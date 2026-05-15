module Portal
  class AiQueriesController < BaseController
    class_attribute :local_db_ai_service_class, default: LocalDbAi::Service
    class_attribute :local_db_ai_health_check_class, default: LocalDbAi::HealthCheck

    def show
      authorize :ai_query, :show?
      @question = ""
      @health = self.class.local_db_ai_health_check_class.new.call
    end

    def create
      authorize :ai_query, :create?
      @question = ai_query_params[:question].to_s.strip
      @health   = self.class.local_db_ai_health_check_class.new.call
      @result        = self.class.local_db_ai_service_class.new(question: @question, user: current_user).call
      @multi_results = @result[:multi_results] if @result.success? && @result[:multi_results].present?

      render :show, status: @result.success? ? :ok : :unprocessable_entity, formats: [:html]
    end

    def export
      authorize :ai_query, :create?
      question = export_params[:question].to_s.strip
      format   = export_params[:export_format].to_s

      result = self.class.local_db_ai_service_class.new(question: question, user: current_user).call
      return redirect_to portal_ai_query_path, alert: result.message unless result.success?

      rows    = result[:rows]    || []
      columns = result[:columns] || []
      fname   = "vv_query_#{Date.today}"

      case format
      when "xlsx"
        xlsx_data = build_xlsx(columns, rows, question)
        send_data xlsx_data, filename: "#{fname}.xlsx",
                  type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                  disposition: "attachment"
      else
        csv_data = build_csv(columns, rows)
        send_data csv_data, filename: "#{fname}.csv",
                  type: "text/csv", disposition: "attachment"
      end
    end

    private

    def ai_query_params
      params.fetch(:ai_query, ActionController::Parameters.new).permit(:question)
    end

    def export_params
      params.permit(:question, :export_format)
    end

    def build_csv(columns, rows)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << columns.map(&:humanize)
        rows.each { |row| csv << columns.map { |c| row[c] } }
      end
    end

    def build_xlsx(columns, rows, question)
      package = Axlsx::Package.new
      wb = package.workbook
      styles = wb.styles
      header_style = styles.add_style bg_color: "2D6A4F", fg_color: "FFFFFF",
                                      b: true, sz: 11, alignment: { horizontal: :center }
      even_row = styles.add_style bg_color: "F0FAF5"

      wb.add_worksheet(name: "Query Result") do |sheet|
        sheet.add_row ["Question: #{question}"], style: styles.add_style(b: true, sz: 12)
        sheet.add_row ["Generated: #{Time.current.strftime('%d %b %Y %H:%M')}"]
        sheet.add_row []
        sheet.add_row columns.map(&:humanize), style: header_style
        rows.each_with_index do |row, i|
          style = i.even? ? even_row : nil
          sheet.add_row columns.map { |c| row[c] }, style: style
        end
        sheet.column_widths(*Array.new(columns.length, 20))
      end
      package.to_stream.read
    end
  end
end
