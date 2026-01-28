module Api
  module V1
    class QuotesController < BaseController
      def index
        quotes = if params[:lead_id].present?
                   lead = Lead.find(params[:lead_id])
                   lead.quotes
                 else
                   Quote.all
                 end
        quotes = quotes.includes(:quote_line_items, :lead).order(created_at: :desc)
        render_json({ quotes: quotes.as_json(include: :quote_line_items) })
      end

      def show
        quote = Quote.includes(:quote_line_items).find(params[:id])
        render_json({ quote: quote.as_json(include: :quote_line_items) })
      end
    end
  end
end
