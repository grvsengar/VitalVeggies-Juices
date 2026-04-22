class ArticlesController < ApplicationController
  def index
    @articles = Article.published
    @featured_article = @articles.first
    @hero_grid_articles = @articles.offset(1).limit(4)
    @favorite_articles = @articles.offset(5).limit(4)
    @favorite_articles = @articles.limit(4) if @favorite_articles.empty?
  end

  def show
    @article = Article.published.find_by!(slug: params[:id])
    @related_articles = Article.published.where.not(id: @article.id).limit(3)
  end
end
