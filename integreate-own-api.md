You are an expert Ruby on Rails architect and senior AI engineer. 

### Objective
I want to build a local, private Text-to-SQL AI system entirely integrated inside my existing Ruby on Rails application. This system must translate natural language admin queries into safe SQL statements and execute them against my database. 

### Core Constraints & Architecture
1. NO External APIs: Do not use OpenAI, Anthropic, or external paid APIs. 
2. Local Processing: The solution must leverage a local tool called 'Ollama' running an open-source model (like `qwen2.5-coder` or `llama3`) on localhost.
3. Language Stack: Use Ruby on Rails. If a Gem exists to handle Ollama interactions (like `ollama-ai` or standard HTTP clients), use that. Do not spin up a separate Python microservice unless absolutely necessary.
4. Security is Critical: The system must absolutely prevent SQL injection attacks. The AI should only output a read-only SQL query, and the code must enforce a safe sandbox execution layer.

### What I Need From You
Please provide a complete, production-ready codebase implementation containing:

1. Setup Instructions: Shell commands to install Ollama, pull a specialized SQL model, and any required Rails Gemfile configurations.
2. The Database Schema Context: A methodology or service module that automatically extracts my Rails database schema (ActiveRecord schema or specific models like Product, Order, User) and packages it into a clean markdown structure to feed as prompt context to the local AI.
3. The AI Integration Service: A clean Rails Service Object (`app/services/local_db_ai_service.rb`) that:
   - Takes a natural language string.
   - Inject the system prompt and database schema context.
   - Makes a local HTTP/Gem call to Ollama.
   - Cleans and strips the markdown code blocks from the AI's response to get a raw SQL string.
4. The Secure Execution Layer: A method that safely runs the generated SQL query in a read-only transaction, catching database errors or syntax errors gracefully without crashing the web application.
5. Code Example: Show a small implementation example of a mock `Product` and `Order` model, and write a test or runner script showing how typing "Give me the total revenue from completed orders last week" transforms into SQL and outputs data.

Please output clean, well-commented Ruby on Rails code using modern best practices.

##Here is the exact schema for the tables you need to query:  /home/bitcot/Desktop/VitalVeggies-Juices/db/schema.rb

---

## Additional App-Specific Requirements For This Repository

Use the actual VitalVeggies data model when generating the solution. The implementation should not be generic ecommerce boilerplate.

### High-Priority Tables To Support First
Start with a strict allowlist for these tables only:

- `orders`
- `order_items`
- `products`
- `categories`
- `users`
- `addresses`
- `reviews`
- `promotions`
- `newsletter_signups`

Other content tables like `articles`, `faqs`, and `testimonials` can be added later, but the first version should focus on operational and sales reporting.

### Important Enum / Business Meanings From The Current Rails Models
The SQL generator must be told about these enum mappings explicitly because the database stores integers:

- `orders.status`: `pending=0`, `confirmed=1`, `preparing=2`, `out_for_delivery=3`, `delivered=4`, `cancelled=5`
- `products.product_kind`: `juice=0`, `fruit=1`, `vegetable=2`, `combo=3`
- `users.role`: `admin=0`, `manager=1`, `buyer=2`

The prompt context should also mention:

- `orders.total` is the final order amount.
- `orders.subtotal` is before discount and delivery adjustments.
- `orders.payment_status` is a string such as `"pending"` or `"paid"`.
- `order_items.line_total` already stores `quantity * unit_price`.
- `products.active = true` means the product is live.

### Sensitive Columns The AI Must Not Expose By Default
Do not include these columns in normal analytics responses unless a developer explicitly opts in:

- `users.password_digest`
- `users.password_salt`
- `users.invitation_token`
- `orders.gateway_signature`
- `orders.gateway_order_id`
- `orders.gateway_payment_id`
- `orders.tracking_token`

The schema summarizer service should either remove these fields from prompt context or mark them as restricted.

### Required SQL Safety Rules
The secure execution layer should reject any AI output unless all of the following are true:

1. It is exactly one SQL statement.
2. It starts with `SELECT` or `WITH`.
3. It contains no mutation keywords such as `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `TRUNCATE`, `CREATE`, `GRANT`, `REVOKE`, `COPY`, `CALL`, or `DO`.
4. It does not reference tables outside the allowlist.
5. It does not reference restricted columns unless explicitly permitted.

For PostgreSQL execution, prefer these runtime protections:

- run inside a transaction with `SET LOCAL transaction_read_only = on`
- apply a short `statement_timeout` such as 3 to 5 seconds
- apply a row limit fallback if the query does not include one
- return structured errors instead of raising raw DB exceptions into the UI

### Prefer Structured Model Output From Ollama
Do not rely only on free-form markdown cleanup if it can be avoided. If the chosen Ollama model supports JSON mode, ask it to return:

```json
{
  "sql": "SELECT ...",
  "summary": "plain English explanation",
  "assumptions": ["..."]
}
```

Then validate and execute only the `sql` field. Keep the markdown code-block stripping logic as a fallback, not the primary contract.

### Rails Implementation Requirements
Please organize the production code into small service objects instead of one large class. Preferred structure:

- `app/services/local_db_ai/schema_context_builder.rb`
- `app/services/local_db_ai/prompt_builder.rb`
- `app/services/local_db_ai/ollama_client.rb`
- `app/services/local_db_ai/sql_validator.rb`
- `app/services/local_db_ai/query_executor.rb`
- `app/services/local_db_ai/service.rb`

Also add:

- a plain PORO result object or hash contract for success/error responses
- Rails logger instrumentation for prompt size, model name, execution time, and rejected queries
- unit tests for validator and executor
- one integration-style test for a real natural-language prompt

### App-Specific Example Questions The System Should Handle
Use examples grounded in this schema, not placeholder examples:

- "Give me total revenue from delivered orders in the last 7 days"
- "Which 5 products sold the most units this month?"
- "Show pending and confirmed orders grouped by day"
- "How many active products are low on stock?"
- "Which categories generated the highest revenue this month?"
- "How many newsletter signups were created this week?"

### Recommended First-Version Scope
For V1, only allow admin or manager users to access this feature, and keep it inside an internal dashboard or Rails console runner. Do not expose it to buyers or public endpoints.

If possible, also include a query audit trail such as `AiQueryLog` with:

- requesting user id
- natural language question
- generated SQL
- execution status
- execution duration
- number of rows returned

### Important Note About The Existing App
This repository already has commerce-oriented models and enums in:

- `app/models/order.rb`
- `app/models/product.rb`
- `app/models/user.rb`

Use those model definitions to enrich the prompt context, not just `db/schema.rb`. The final implementation should reflect the actual business semantics from those models.
