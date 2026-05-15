module LocalDbAi
  class Service
    def initialize(question:, user:, client: OllamaClient.new, executor: QueryExecutor.new,
                   schema_builder: SchemaContextBuilder.new, live_context_builder: LiveContextBuilder.new)
      normalized          = InputNormalizer.normalize(question.to_s.strip)
      @question           = normalized.text
      @normalized_result  = normalized
      @user               = user
      @client             = client
      @executor           = executor
      @schema_builder     = schema_builder
      @live_context_builder = live_context_builder
    end

    def call
      return failure("disabled", "Local DB AI is disabled.") unless LocalDbAi.config.enabled
      return failure("blank_question", "Enter a question before running the query.") if question.blank?

      # Step 1: instant conversational reply (run on original intent, pre-normalization)
      if (chat_reply = ConversationHandler.handle(question))
        return Result.success(
          sql: nil, summary: chat_reply, assumptions: [], columns: [], rows: [],
          row_count: nil, model: "template", query_log: nil, conversational: true
        )
      end

      return failure("question_too_short", "Ask a reporting question like 'total revenue last 7 days'.") if question_too_short?

      # Step 2: detect compound/multi-intent question and run each sub-query
      sub_questions = MultiQuerySplitter.split(question)
      if sub_questions
        results = sub_questions.map do |sub_q|
          svc = self.class.new(question: sub_q, user: @user, client: @client,
                               executor: @executor, schema_builder: @schema_builder,
                               live_context_builder: @live_context_builder)
          { question: sub_q, result: svc.call }
        end
        return Result.success(
          multi_results: results, conversational: false,
          corrected_from: (@normalized_result.corrected ? @normalized_result.original : nil)
        )
      end

      # Step 3: cache check — identical question answered instantly
      QueryCache.fetch(question) do
        result = run_query
        # Tag result with correction info so the view can show "Did you mean…"
        if @normalized_result.corrected && result.success?
          Result.success(result.payload.merge(corrected_from: @normalized_result.original))
        else
          result
        end
      end
    end

    private

    attr_reader :question, :user, :client, :executor, :schema_builder, :live_context_builder

    def run_query
      query_log  = create_query_log!
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Step 3: template engine — handles ~90% of queries in <5ms
      tpl = SqlTemplateEngine.match(question)
      if tpl.matched
        Rails.logger.info("[LocalDbAi] template match for: #{question}")
        execution = executor.call(tpl.sql)

        if execution.success?
          duration_ms = elapsed_ms(started_at)
          update_query_log!(query_log, status: "succeeded", sql: execution[:sql],
                            execution_duration_ms: duration_ms, row_count: execution[:row_count])
          return Result.success(
            sql: execution[:sql], summary: tpl.summary, assumptions: [],
            columns: execution[:columns], rows: execution[:rows],
            row_count: execution[:row_count], model: "template", query_log:, from_cache: false
          )
        end
        # Template SQL failed — fall through to Ollama with error context
        Rails.logger.warn("[LocalDbAi] template SQL failed: #{execution.message} — falling back to Ollama")
      end

      # Step 4: Ollama with self-healing retry
      schema       = schema_builder.build
      live_context = live_context_builder.build
      prompts      = PromptBuilder.new(question:, schema_context: "#{schema}\n\n#{live_context}").build

      Rails.logger.info("[LocalDbAi] ollama request model=#{client.model} chars=#{prompts[:user_prompt].length}")
      ai_response = client.generate(**prompts)
      execution   = executor.call(ai_response[:sql])

      # Step 5: self-healing retry on SQL error
      if execution.failure?
        Rails.logger.warn("[LocalDbAi] attempt 1 failed: #{execution.message} — retrying")
        ai_response, execution = retry_with_error(prompts, ai_response[:sql], execution.message)
      end

      duration_ms = elapsed_ms(started_at)

      if execution.failure?
        update_query_log!(query_log, status: "rejected", sql: ai_response[:sql],
                          execution_duration_ms: duration_ms, error_message: execution.message)
        return failure(execution.code, execution.message,
                       sql: ai_response[:sql], summary: ai_response[:summary],
                       assumptions: ai_response[:assumptions])
      end

      update_query_log!(query_log, status: "succeeded", sql: execution[:sql],
                        execution_duration_ms: duration_ms, row_count: execution[:row_count])

      Result.success(
        sql: execution[:sql], summary: ai_response[:summary],
        assumptions: ai_response[:assumptions], columns: execution[:columns],
        rows: execution[:rows], row_count: execution[:row_count],
        model: client.model, query_log:, from_cache: false
      )
    rescue Error => e
      update_query_log!(query_log, status: "failed", execution_duration_ms: elapsed_ms(started_at), error_message: e.message)
      failure("ollama_error", e.message)
    rescue StandardError => e
      update_query_log!(query_log, status: "failed", execution_duration_ms: elapsed_ms(started_at), error_message: e.message)
      failure("unexpected_error", e.message)
    end

    def retry_with_error(original_prompts, bad_sql, error_message)
      retry_prompt = original_prompts.merge(
        user_prompt: "#{original_prompts[:user_prompt]}\n\nPREVIOUS SQL FAILED:\n#{bad_sql}\nERROR: #{error_message}\nFix and return corrected JSON only."
      )
      ai_response = client.generate(**retry_prompt)
      [ai_response, executor.call(ai_response[:sql])]
    rescue StandardError => e
      Rails.logger.warn("[LocalDbAi] retry exception: #{e.message}")
      [{ sql: bad_sql, summary: "", assumptions: [] },
       Result.failure(code: "retry_failed", message: e.message)]
    end

    def create_query_log!
      AiQueryLog.create!(user:, question:, llm_model: client.model, status: "pending")
    end

    def update_query_log!(query_log, attributes)
      query_log&.update!(attributes)
    end

    def failure(code, message, payload = {})
      Result.failure(code:, message:, payload:)
    end

    def elapsed_ms(started_at)
      return 0 unless started_at
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    # Single meaningful domain words are valid queries ("orders", "revenue", "products")
    # Only block truly empty or nonsensical input (< 3 chars after stripping punctuation)
    SINGLE_WORD_ALLOWLIST = %w[
      orders revenue products customers reviews promotions inventory summary
      faqs faq testimonials articles categories managers newsletter stock
      combo combos delivered pending cancelled confirmed preparing
    ].freeze

    def question_too_short?
      cleaned = question.squish.gsub(/[?!.,]+\z/, "").strip
      return false if SINGLE_WORD_ALLOWLIST.include?(cleaned.downcase)
      cleaned.length < 3
    end
  end
end
