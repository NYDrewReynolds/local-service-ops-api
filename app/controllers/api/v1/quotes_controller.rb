module Api
  module V1
    class QuotesController < BaseController
      def index
        lead = Lead.find(params[:lead_id])
        quotes = lead.quotes.includes(:quote_line_items).order(created_at: :desc)
        render_json({ quotes: quotes.as_json(include: :quote_line_items) })
      end

      def show
        quote = Quote.includes(:quote_line_items).find(params[:id])
        render_json({ quote: quote.as_json(include: :quote_line_items) })
      end
    end
  end
end
