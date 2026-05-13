class Avo::Actions::GenerateShortVideo < Avo::BaseAction
  self.name = "Generate Marketing Short"
  self.standalone = false

  def handle(**args)
    # The debug logs revealed this Avo version uses :records instead of :models
    models = Array(args[:records] || args[:models] || args[:model] || args[:record])
    article = models.first
    
    return error "No article selected." unless article

    redirect_to "/manager/marketing-studio?article_id=#{article.id}"
  end
end
