module Manager
  class MarketingStudioController < ApplicationController
    MAX_REMOTE_AUDIO_BYTES = 25.megabytes

    before_action :require_manager!
    before_action :set_article, only: %i[show video]

    def show
      @hide_site_chrome = true # Premium immersive experience
    end

    def video
      return head :not_found unless @article.video.present? && File.exist?(@article.video.path)

      response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
      response.headers["Cross-Origin-Embedder-Policy"] = "credentialless"
      response.headers["Accept-Ranges"] = "bytes"

      send_file @article.video.path,
                type: @article.video.file.content_type.presence || "video/mp4",
                disposition: "inline",
                filename: File.basename(@article.video.path)
    end

    def audio
      remote_uri = safe_remote_audio_uri
      return render plain: "Invalid audio URL", status: :unprocessable_entity unless remote_uri

      response = fetch_remote_audio(remote_uri)
      return render plain: "Audio could not be fetched", status: :bad_gateway unless response&.is_a?(Net::HTTPSuccess)

      content_type = response.content_type.presence || "application/octet-stream"
      return render plain: "Remote file is not audio", status: :unsupported_media_type unless content_type.start_with?("audio/") || content_type == "application/octet-stream"

      body = response.body.to_s
      return render plain: "Remote audio is too large", status: :payload_too_large if body.bytesize > MAX_REMOTE_AUDIO_BYTES

      response_headers_for_audio(content_type)
      send_data body,
                type: content_type,
                disposition: "inline",
                filename: "background-audio#{audio_extension(content_type)}"
    end

    private

    def set_article
      @article = Article.find(params[:article_id])
    end

    def require_manager!
      unless current_user&.manager? || current_user&.admin?
        redirect_to root_path, alert: "Not authorized."
      end
    end

    def safe_remote_audio_uri
      uri = URI.parse(params[:url].to_s)
      return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return if uri.host.blank? || unsafe_remote_host?(uri.host)

      uri
    rescue URI::InvalidURIError
      nil
    end

    def unsafe_remote_host?(host)
      ip = IPSocket.getaddress(host)
      address = IPAddr.new(ip)

      address.loopback? || address.private? || address.link_local?
    rescue SocketError, IPAddr::InvalidAddressError
      true
    end

    def fetch_remote_audio(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "audio/*,*/*"
        http.request(request)
      end
    rescue StandardError
      nil
    end

    def response_headers_for_audio(content_type)
      response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
      response.headers["Cross-Origin-Embedder-Policy"] = "credentialless"
      response.headers["Content-Type"] = content_type
    end

    def audio_extension(content_type)
      case content_type
      when "audio/mpeg" then ".mp3"
      when "audio/wav", "audio/x-wav" then ".wav"
      when "audio/ogg" then ".ogg"
      when "audio/mp4", "audio/aac" then ".m4a"
      else ".audio"
      end
    end
  end
end
