import { Controller } from "@hotwired/stimulus"

export default class FFmpegStudioController extends Controller {
    static targets = [
        "videoPlayer", "startTime", "endTime", "timer",
        "generateBtn", "outputSection", "outputVideo",
        "downloadBtn", "overlay", "progressText", "progressBar",
        "format", "status", "durationLabel", "selectionLabel",
        "errorPanel", "errorText", "fitMode", "compression",
        "textOverlay", "audioMode", "audioSource", "audioInput",
        "audioUrl", "previewStage", "previewText", "effectPreset",
        "brightness", "contrast", "saturation", "warmth", "blur",
        "transition", "transitionDuration", "transitionDurationLabel",
        "segmentsList", "segmentsCount", "sequenceDuration",
        "loopToggle", "undoBtn", "redoBtn", "autosaveStatus",
        "exportName", "originalVolume", "musicVolume", "musicFadeIn",
        "musicFadeOut", "textPosition", "textStyle", "textSize",
        "textSizeValue", "playbackSpeed", "playbackSpeedLabel",
        "zoom", "zoomLabel", "offsetX", "offsetXLabel",
        "offsetY", "offsetYLabel"
    ]

    static values = { videoUrl: String, audioProxyUrl: String, articleId: String }

    async connect() {
        this.ffmpeg = null
        this.ffmpegLogs = []
        this.isLoaded = false
        this.engineLoadPromise = null
        this.videoReady = false
        this.sourceHasAudio = true
        this.generatedUrl = null
        this.segments = []
        this.history = []
        this.historyIndex = -1
        this.restoringState = false
        this.loopPreviewEnabled = false
        this.previewSelectionActive = false
        this.autosaveTimer = null
        this.boundHandleKeydown = this.handleKeydown.bind(this)

        this.bindVideoEvents()
        this.bindRealtimeControls()
        document.addEventListener("keydown", this.boundHandleKeydown)

        this.restoreSavedState()
        this.toggleAudioInputs()
        this.updateTransitionLabel()
        this.renderSegments()
        this.refreshPreview()
        this.updateLoopUi()
        this.updateDownloadFileName("mp4")
        this.syncHistoryButtons()
        this.pushHistory({ force: true, silent: true })
        this.setGenerateDisabled(true)
        this.setStatus("Preview ready", "ready")
    }

    disconnect() {
        if (this.generatedUrl) URL.revokeObjectURL(this.generatedUrl)
        if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
        document.removeEventListener("keydown", this.boundHandleKeydown)
    }

    async retry() {
        this.hideError()
        this.setStatus("Preparing engine", "busy")
        try {
            await this.ensureFfmpegLoaded({ interactive: true })
        } catch (_error) {
            // Error state is already surfaced by handleFailure.
        }
    }

    bindVideoEvents() {
        this.videoPlayerTarget.addEventListener("loadedmetadata", () => {
            this.videoReady = true
            this.sourceHasAudio = this.detectSourceAudio()
            this.setupTimeline()
            this.refreshPreview()
            this.hideError()
            this.pushHistory({ force: true, silent: true })
            this.setGenerateDisabled(false)
            this.setStatus("Preview ready", "ready")
        })

        this.videoPlayerTarget.addEventListener("timeupdate", () => this.maintainSelectionPlayback())

        this.videoPlayerTarget.addEventListener("pause", () => {
            if (!this.loopPreviewEnabled) this.previewSelectionActive = false
        })

        this.videoPlayerTarget.addEventListener("error", () => {
            this.videoReady = false
            this.setGenerateDisabled(true)
            this.showError("The original video could not be previewed. Re-upload the article video as MP4/WebM or check that the file still exists.")
        })
    }

    bindRealtimeControls() {
        const controls = [
            this.startTimeTarget,
            this.endTimeTarget,
            this.formatTarget,
            this.fitModeTarget,
            this.compressionTarget,
            this.textOverlayTarget,
            this.audioModeTarget,
            this.audioSourceTarget,
            this.audioInputTarget,
            this.audioUrlTarget,
            this.textStyleTarget,
            this.textSizeTarget,
            this.effectPresetTarget,
            this.brightnessTarget,
            this.contrastTarget,
            this.saturationTarget,
            this.warmthTarget,
            this.blurTarget,
            this.transitionTarget,
            this.transitionDurationTarget,
            this.exportNameTarget,
            this.originalVolumeTarget,
            this.musicVolumeTarget,
            this.musicFadeInTarget,
            this.musicFadeOutTarget,
            this.textPositionTarget,
            this.playbackSpeedTarget,
            this.zoomTarget,
            this.offsetXTarget,
            this.offsetYTarget
        ]

        controls.forEach((control) => {
            control.addEventListener("input", () => this.handleControlInput(control))
            control.addEventListener("change", () => this.handleControlCommit(control))
        })
    }

    handleControlInput(control) {
        if (control === this.startTimeTarget || control === this.endTimeTarget) {
            this.previewSelectionActive = false
            this.updateTimer()
            this.scheduleAutosave()
            return
        }

        if (control === this.transitionTarget || control === this.transitionDurationTarget) {
            this.updateTransitionLabel()
            this.renderSegments()
        }

        if (control === this.playbackSpeedTarget || control === this.zoomTarget || control === this.offsetXTarget || control === this.offsetYTarget) {
            this.updateTransformLabels()
        }

        if (control === this.audioModeTarget || control === this.audioSourceTarget) {
            this.toggleAudioInputs()
        }

        if (control === this.exportNameTarget) {
            this.updateDownloadFileName("mp4")
        }

        this.refreshPreview()
        this.scheduleAutosave()
    }

    handleControlCommit(control) {
        this.handleControlInput(control)

        if (control === this.audioInputTarget) {
            this.commitState("Audio source prepared")
            return
        }

        if (control === this.exportNameTarget) {
            this.commitState("Export name updated")
            return
        }

        this.commitState("Edit updated")
    }

    async ensureFfmpegLoaded(options = {}) {
        if (this.isLoaded && this.ffmpeg) return true
        if (this.engineLoadPromise) return this.engineLoadPromise

        this.engineLoadPromise = this.loadFFmpeg(options)
            .finally(() => {
                this.engineLoadPromise = null
            })

        return this.engineLoadPromise
    }

    async loadFFmpeg(options = {}) {
        const { interactive = false } = options

        try {
            if (interactive) this.showOverlay("Loading video engine...", 10)
            this.setStatus("Loading engine", "busy")

            if (!globalThis.FFmpeg) {
                await this.withTimeout(
                    this.loadScript("https://unpkg.com/@ffmpeg/ffmpeg@0.11.6/dist/ffmpeg.min.js"),
                    12000,
                    "FFmpeg loader script timed out"
                )
            }

            const { createFFmpeg } = globalThis.FFmpeg
            if (!this.ffmpeg) {
                this.ffmpeg = createFFmpeg({
                    log: true,
                    corePath: "https://unpkg.com/@ffmpeg/core@0.11.0/dist/ffmpeg-core.js",
                    logger: ({ type, message }) => {
                        this.ffmpegLogs.push(`[${type}] ${message}`)
                        if (this.ffmpegLogs.length > 120) this.ffmpegLogs.shift()
                    }
                })

                if (typeof this.ffmpeg.setProgress === "function") {
                    this.ffmpeg.setProgress(({ ratio }) => {
                        const percent = Math.min(92, Math.max(38, Math.round(ratio * 92)))
                        this.updateProgress("Rendering sequence...", percent)
                    })
                }
            }

            await this.withTimeout(this.ffmpeg.load(), 16000, "FFmpeg core load timed out")
            this.isLoaded = true
            this.setStatus("Engine ready", "ready")
            if (interactive) this.hideOverlay()
            this.setGenerateDisabled(!this.videoReady)
            return true
        } catch (error) {
            this.isLoaded = false
            this.ffmpeg = null

            if (interactive) {
                this.handleFailure(error, "The video engine could not load. Check your internet connection because FFmpeg is loaded from the CDN in development.")
            } else {
                this.hideOverlay()
                this.setStatus("Preview ready", "ready")
            }

            throw error
        }
    }

    loadScript(src) {
        return new Promise((resolve, reject) => {
            if (globalThis.FFmpeg) {
                resolve()
                return
            }

            const existingScript = document.querySelector(`script[src="${src}"]`)
            if (existingScript) {
                if (existingScript.dataset.loaded === "true" || globalThis.FFmpeg) {
                    resolve()
                    return
                }

                existingScript.addEventListener("load", resolve, { once: true })
                existingScript.addEventListener("error", reject, { once: true })
                return
            }

            const script = document.createElement("script")
            script.src = src
            script.crossOrigin = "anonymous"
            script.onload = () => {
                script.dataset.loaded = "true"
                resolve()
            }
            script.onerror = () => reject(new Error(`Could not load ${src}`))
            document.head.appendChild(script)
        })
    }

    withTimeout(promise, timeoutMs, message) {
        return Promise.race([
            promise,
            new Promise((_, reject) => {
                window.setTimeout(() => reject(new Error(message)), timeoutMs)
            })
        ])
    }

    detectSourceAudio() {
        const video = this.videoPlayerTarget
        if (typeof video.mozHasAudio === "boolean") return video.mozHasAudio
        if (video.audioTracks && video.audioTracks.length > 0) return true
        if (typeof video.webkitAudioDecodedByteCount === "number") return video.webkitAudioDecodedByteCount > 0

        return true
    }

    setupTimeline() {
        const duration = this.videoPlayerTarget.duration
        if (!Number.isFinite(duration) || duration <= 0) return

        this.startTimeTarget.min = 0
        this.startTimeTarget.max = duration
        this.startTimeTarget.step = 0.1
        this.startTimeTarget.value = this.startTimeTarget.value || 0

        this.endTimeTarget.min = 0
        this.endTimeTarget.max = duration
        this.endTimeTarget.step = 0.1
        this.endTimeTarget.value = this.endTimeTarget.value || Math.min(duration, 15)

        this.clampSegmentsToDuration(duration)
        this.updateTimer()
    }

    updateTimer() {
        const duration = this.videoPlayerTarget.duration
        if (!Number.isFinite(duration)) return

        let start = Number.parseFloat(this.startTimeTarget.value || "0")
        let end = Number.parseFloat(this.endTimeTarget.value || "0")

        start = Math.max(0, Math.min(start, duration))
        end = Math.max(start + 1, Math.min(end, duration))

        if (end - start > 30) end = start + 30
        if (end > duration) {
            end = duration
            start = Math.max(0, end - 30)
        }

        this.startTimeTarget.value = start
        this.endTimeTarget.value = end
        this.timerTarget.textContent = `${this.formatTime(start)} - ${this.formatTime(end)}`
        this.durationLabelTarget.textContent = `Source length: ${this.formatTime(duration)}`
        this.selectionLabelTarget.textContent = `${Math.round(end - start)}s selected`
        this.videoPlayerTarget.currentTime = start
        this.renderSegments()
    }

    formatTime(seconds) {
        const total = Math.max(0, Number(seconds) || 0)
        const minutes = Math.floor(total / 60)
        const secs = Math.floor(total % 60)
        return `${minutes}:${secs.toString().padStart(2, "0")}`
    }

    previewFilterString() {
        const state = this.visualState()
        const filters = [
            `brightness(${Math.max(0.35, 1 + state.brightness)})`,
            `contrast(${Math.max(0.45, 1 + state.contrast)})`,
            `saturate(${Math.max(0, state.grayscale ? 0 : 1 + state.saturation)})`,
            `sepia(${Math.max(0, state.warmth * 0.85)})`,
            `hue-rotate(${Math.round(state.warmth * -14)}deg)`,
            `blur(${Math.max(0, state.blur)}px)`
        ]

        if (state.grayscale) filters.push("grayscale(1)")
        return filters.join(" ")
    }

    visualState() {
        const state = {
            brightness: Number(this.brightnessTarget.value) / 120,
            contrast: Number(this.contrastTarget.value) / 120,
            saturation: Number(this.saturationTarget.value) / 120,
            warmth: Number(this.warmthTarget.value) / 120,
            blur: Number(this.blurTarget.value) / 2,
            grayscale: false
        }

        switch (this.effectPresetTarget.value) {
            case "cinematic":
                state.contrast += 0.1
                state.saturation -= 0.08
                state.warmth += 0.12
                break
            case "vivid":
                state.contrast += 0.08
                state.saturation += 0.18
                state.brightness += 0.03
                break
            case "dreamy":
                state.brightness += 0.08
                state.contrast -= 0.06
                state.saturation += 0.06
                state.blur += 0.8
                break
            case "noir":
                state.grayscale = true
                state.contrast += 0.18
                state.brightness += 0.02
                break
            default:
                break
        }

        return state
    }

    refreshPreview() {
        this.videoPlayerTarget.style.filter = this.previewFilterString()
        this.videoPlayerTarget.style.objectFit = this.fitModeTarget.value === "crop" ? "cover" : "contain"

        const caption = this.textOverlayTarget.value.trim()
        const position = this.textPositionTarget.value || "bottom"
        this.previewTextTarget.dataset.position = position
        this.updateTextSizeLabel()

        if (caption) {
            this.previewTextTarget.textContent = caption
            this.applyPreviewCaptionStyle()
            this.previewTextTarget.classList.remove("hidden")
        } else {
            this.previewTextTarget.textContent = ""
            this.previewTextTarget.classList.add("hidden")
        }

        if (this.audioModeTarget.value === "mute") {
            this.videoPlayerTarget.muted = true
            this.videoPlayerTarget.volume = 0
        } else {
            this.videoPlayerTarget.muted = false
            this.videoPlayerTarget.volume = Math.min(1, Math.max(0, this.originalAudioGain()))
        }

        if (this.hasPlaybackSpeedTarget) {
            const speed = Number(this.playbackSpeedTarget.value) || 1.0
            this.videoPlayerTarget.playbackRate = speed
        }

        if (this.hasZoomTarget && this.hasOffsetXTarget && this.hasOffsetYTarget) {
            const zoom = Number(this.zoomTarget.value) || 1.0
            const offX = Number(this.offsetXTarget.value) || 0
            const offY = Number(this.offsetYTarget.value) || 0
            this.videoPlayerTarget.style.transform = `scale(${zoom}) translate(${offX}%, ${offY}%)`
        }
    }

    updateTransformLabels() {
        if (this.hasPlaybackSpeedLabelTarget) this.playbackSpeedLabelTarget.textContent = `${Number(this.playbackSpeedTarget.value).toFixed(1)}x`
        if (this.hasZoomLabelTarget) this.zoomLabelTarget.textContent = `${Number(this.zoomTarget.value).toFixed(2)}x`
        if (this.hasOffsetXLabelTarget) this.offsetXLabelTarget.textContent = `${this.offsetXTarget.value}%`
        if (this.hasOffsetYLabelTarget) this.offsetYLabelTarget.textContent = `${this.offsetYTarget.value}%`
    }

    updateTextSizeLabel() {
        if (!this.hasTextSizeValueTarget) return
        this.textSizeValueTarget.textContent = `${this.captionBaseSize()}px`
    }

    captionBaseSize() {
        return Number(this.textSizeTarget.value || 40)
    }

    captionStyle() {
        return this.textStyleTarget.value || "classic"
    }

    captionAppearance(dimensions = null) {
        const baseSize = this.captionBaseSize()
        const scale = dimensions ? (dimensions.font / 40) : 1
        const fontSize = Math.max(18, Math.round(baseSize * scale))
        const style = this.captionStyle()

        const appearances = {
            classic: {
                fontFamily: "Georgia, serif",
                fontWeight: "700",
                letterSpacing: "0",
                textTransform: "none",
                color: "#ffffff",
                background: "rgba(8, 10, 12, 0.76)",
                borderColor: "rgba(255, 255, 255, 0.08)",
                boxShadow: "0 12px 24px rgba(0, 0, 0, 0.28)",
                radius: 24,
                paddingY: 26
            },
            glow: {
                fontFamily: "\"Trebuchet MS\", sans-serif",
                fontWeight: "800",
                letterSpacing: "0.04em",
                textTransform: "uppercase",
                color: "#f8feff",
                background: "rgba(14, 33, 47, 0.78)",
                borderColor: "rgba(109, 176, 255, 0.42)",
                boxShadow: "0 0 28px rgba(109, 176, 255, 0.24)",
                textShadow: "0 0 14px rgba(109, 176, 255, 0.45)",
                radius: 28,
                paddingY: 28
            },
            badge: {
                fontFamily: "\"Trebuchet MS\", sans-serif",
                fontWeight: "800",
                letterSpacing: "0.05em",
                textTransform: "uppercase",
                color: "#102016",
                background: "rgba(219, 244, 222, 0.95)",
                borderColor: "rgba(102, 192, 143, 0.35)",
                boxShadow: "0 12px 24px rgba(0, 0, 0, 0.18)",
                radius: 999,
                paddingY: 22
            },
            typewriter: {
                fontFamily: "\"Courier New\", monospace",
                fontWeight: "700",
                letterSpacing: "0.08em",
                textTransform: "uppercase",
                color: "#f6efe3",
                background: "rgba(18, 16, 14, 0.84)",
                borderColor: "rgba(230, 184, 106, 0.26)",
                boxShadow: "0 12px 24px rgba(0, 0, 0, 0.28)",
                radius: 14,
                paddingY: 22
            },
            minimal: {
                fontFamily: "\"Trebuchet MS\", sans-serif",
                fontWeight: "700",
                letterSpacing: "0.01em",
                textTransform: "none",
                color: "#ffffff",
                background: "rgba(7, 10, 14, 0.42)",
                borderColor: "rgba(255, 255, 255, 0.05)",
                boxShadow: "none",
                radius: 18,
                paddingY: 18
            }
        }

        return {
            fontSize,
            ...appearances[style]
        }
    }

    applyPreviewCaptionStyle() {
        const appearance = this.captionAppearance()
        this.previewTextTarget.dataset.style = this.captionStyle()
        Object.assign(this.previewTextTarget.style, {
            fontFamily: appearance.fontFamily,
            fontWeight: appearance.fontWeight,
            letterSpacing: appearance.letterSpacing,
            textTransform: appearance.textTransform,
            color: appearance.color,
            background: appearance.background,
            borderColor: appearance.borderColor,
            boxShadow: appearance.boxShadow,
            borderRadius: appearance.radius === 999 ? "999px" : `${appearance.radius}px`,
            fontSize: `${appearance.fontSize}px`,
            textShadow: appearance.textShadow || "none"
        })
    }

    updateTransitionLabel() {
        const value = Number.parseFloat(this.transitionDurationTarget.value || "0.4")
        const typeLabel = this.transitionTarget.options[this.transitionTarget.selectedIndex]?.text || "transition"
        this.transitionDurationLabelTarget.textContent = `${value.toFixed(1)}s ${typeLabel.toLowerCase()} between clips`
    }

    toggleAudioInputs() {
        const musicMode = this.audioModeTarget.value === "music"
        const online = this.audioSourceTarget.value === "online"

        this.audioSourceTarget.classList.toggle("hidden", !musicMode)
        this.audioSourceTarget.disabled = !musicMode
        this.audioInputTarget.classList.toggle("hidden", !musicMode || online)
        this.audioInputTarget.disabled = !musicMode || online
        this.audioUrlTarget.classList.toggle("hidden", !musicMode || !online)
        this.audioUrlTarget.disabled = !musicMode || !online
    }

    currentSelectionSegment() {
        const start = Number.parseFloat(this.startTimeTarget.value || "0")
        const end = Number.parseFloat(this.endTimeTarget.value || "1")
        return {
            id: "selection",
            title: "Current selection",
            start,
            end,
            duration: Math.max(1, end - start)
        }
    }

    activeSegments() {
        return this.segments.length > 0 ? this.segments : [this.currentSelectionSegment()]
    }

    addSegment() {
        if (!this.videoReady) return
        if (this.segments.length >= 8) {
            this.showError("Sequence is capped at 8 clips for browser-safe rendering. Merge this edit before adding more.")
            return
        }

        const segment = this.currentSelectionSegment()
        const id = typeof crypto !== "undefined" && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`
        this.segments.push({
            ...segment,
            id,
            title: `Clip ${this.segments.length + 1}`
        })
        this.renderSegments()
        this.commitState("Clip added")
    }

    splitClip() {
        if (!this.videoReady) return
        const currentTime = this.videoPlayerTarget.currentTime
        const start = Number.parseFloat(this.startTimeTarget.value || "0")
        const end = Number.parseFloat(this.endTimeTarget.value || "1")

        if (currentTime <= start || currentTime >= end) return

        const id1 = typeof crypto !== "undefined" && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-1`
        const id2 = typeof crypto !== "undefined" && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-2`

        const baseTitle = this.segments.length === 0 ? "Clip" : `Clip ${this.segments.length}`

        this.segments.push({
            id: id1,
            title: `${baseTitle} A`,
            start: start,
            end: currentTime,
            duration: currentTime - start
        })
        this.segments.push({
            id: id2,
            title: `${baseTitle} B`,
            start: currentTime,
            end: end,
            duration: end - currentTime
        })

        this.startTimeTarget.value = currentTime
        this.updateTimer()
        this.renderSegments()
        this.commitState("Clip split")
    }

    clearSegments() {
        this.segments = []
        this.renderSegments()
        this.commitState("Sequence cleared")
    }

    previewSegment(event) {
        const index = Number(event.currentTarget.dataset.index)
        const segment = this.segments[index]
        if (!segment) return

        this.setRange(segment.start, segment.end, { commit: true, statusText: `${segment.title} loaded` })
    }

    removeSegment(event) {
        const index = Number(event.currentTarget.dataset.index)
        this.segments.splice(index, 1)
        this.renderSegments()
        this.commitState("Clip removed")
    }

    moveSegmentUp(event) {
        const index = Number(event.currentTarget.dataset.index)
        if (index <= 0) return
            ;[this.segments[index - 1], this.segments[index]] = [this.segments[index], this.segments[index - 1]]
        this.renderSegments()
        this.commitState("Sequence updated")
    }

    moveSegmentDown(event) {
        const index = Number(event.currentTarget.dataset.index)
        if (index >= this.segments.length - 1) return
            ;[this.segments[index + 1], this.segments[index]] = [this.segments[index], this.segments[index + 1]]
        this.renderSegments()
        this.commitState("Sequence updated")
    }

    renderSegments() {
        const segments = this.activeSegments()
        this.segmentsCountTarget.textContent = `${segments.length} clip${segments.length === 1 ? "" : "s"}`
        this.sequenceDurationTarget.textContent = this.formatTime(this.sequenceDuration(segments))

        if (this.segments.length === 0) {
            const current = this.currentSelectionSegment()
            this.segmentsListTarget.innerHTML = `
        <article class="studio-segment-card">
          <div class="studio-segment-index">01</div>
          <div class="studio-segment-copy">
            <strong>Live selection</strong>
            <span>${this.formatTime(current.start)} - ${this.formatTime(current.end)} • ${Math.round(current.duration)}s</span>
          </div>
          <div class="studio-segment-actions">
            <button type="button" data-action="ffmpeg-studio#addSegment">+</button>
          </div>
        </article>
      `
            return
        }

        this.segmentsListTarget.innerHTML = this.segments.map((segment, index) => `
      <article class="studio-segment-card">
        <div class="studio-segment-index">${String(index + 1).padStart(2, "0")}</div>
        <div class="studio-segment-copy">
          <strong>${segment.title}</strong>
          <span>${this.formatTime(segment.start)} - ${this.formatTime(segment.end)} • ${Math.round(segment.duration)}s</span>
        </div>
        <div class="studio-segment-actions">
          <button type="button" data-index="${index}" data-action="ffmpeg-studio#previewSegment">Use</button>
          <button type="button" data-index="${index}" data-action="ffmpeg-studio#moveSegmentUp" ${index === 0 ? "disabled" : ""}>↑</button>
          <button type="button" data-index="${index}" data-action="ffmpeg-studio#moveSegmentDown" ${index === this.segments.length - 1 ? "disabled" : ""}>↓</button>
          <button type="button" data-index="${index}" data-action="ffmpeg-studio#removeSegment">×</button>
        </div>
      </article>
    `).join("")
    }

    sequenceDuration(segments) {
        const total = segments.reduce((sum, segment) => sum + segment.duration, 0)
        if (segments.length <= 1 || this.transitionTarget.value === "none") return total

        return Math.max(1, total - ((segments.length - 1) * this.transitionSeconds()))
    }

    transitionSeconds() {
        return this.transitionTarget.value === "none" ? 0 : Number.parseFloat(this.transitionDurationTarget.value || "0.4")
    }

    async setPreset(event) {
        const preset = event.currentTarget.dataset.preset
        const duration = this.videoPlayerTarget.duration
        if (!Number.isFinite(duration)) return

        this.element.querySelectorAll(".preset-btn[data-preset]").forEach((button) => button.classList.remove("active"))
        event.currentTarget.classList.add("active")

        if (preset === "teaser") {
            this.setRange(0, Math.min(duration, 10), { commit: true, statusText: "Teaser range loaded" })
        } else if (preset === "smart") {
            await this.smartPickHighlight()
            this.commitState("Smart pick ready")
        } else if (preset === "action") {
            const mid = duration / 2
            this.setRange(Math.max(0, mid - 6), Math.min(duration, mid + 6), { commit: true, statusText: "Action range loaded" })
        } else if (preset === "promo") {
            this.setRange(Math.max(0, duration * 0.25), Math.min(duration, duration * 0.25 + 18), { commit: true, statusText: "Promo range loaded" })
        } else if (preset === "last") {
            this.setRange(Math.max(0, duration - 12), duration, { commit: true, statusText: "Final hook loaded" })
        }
    }

    setRange(start, end, options = {}) {
        const { commit = false, statusText = "Selection updated" } = options
        this.startTimeTarget.value = start
        this.endTimeTarget.value = end
        this.updateTimer()

        if (commit) this.commitState(statusText)
    }

    async smartPickHighlight() {
        const video = this.videoPlayerTarget
        const duration = video.duration
        const sampleCount = Math.min(14, Math.max(5, Math.floor(duration / 3)))
        const canvas = document.createElement("canvas")
        const context = canvas.getContext("2d", { willReadFrequently: true })
        const originalTime = video.currentTime
        let best = { time: Math.min(duration, 6), score: -1 }

        canvas.width = 96
        canvas.height = 54
        this.setStatus("Reading video", "busy")

        for (let index = 0; index < sampleCount; index += 1) {
            const time = Math.min(duration - 0.2, (duration / (sampleCount + 1)) * (index + 1))
            await this.seekVideo(time)
            context.drawImage(video, 0, 0, canvas.width, canvas.height)
            const frame = context.getImageData(0, 0, canvas.width, canvas.height)
            const score = this.frameInterestScore(frame.data)

            if (score > best.score) best = { time, score }
        }

        await this.seekVideo(originalTime)
        const highlightLength = Math.min(12, duration)
        const start = Math.max(0, Math.min(best.time - highlightLength / 2, duration - highlightLength))
        this.setRange(start, start + highlightLength)
    }

    seekVideo(time) {
        return new Promise((resolve) => {
            const onSeeked = () => resolve()
            this.videoPlayerTarget.addEventListener("seeked", onSeeked, { once: true })
            this.videoPlayerTarget.currentTime = time
        })
    }

    frameInterestScore(data) {
        let sum = 0
        let sumSquares = 0
        let edgeScore = 0
        let previous = 0
        const pixels = data.length / 4

        for (let index = 0; index < data.length; index += 16) {
            const luminance = (data[index] * 0.2126) + (data[index + 1] * 0.7152) + (data[index + 2] * 0.0722)
            sum += luminance
            sumSquares += luminance * luminance
            edgeScore += Math.abs(luminance - previous)
            previous = luminance
        }

        const samplePixels = pixels / 4
        const mean = sum / samplePixels
        const variance = (sumSquares / samplePixels) - (mean * mean)
        return variance + (edgeScore / samplePixels)
    }

    async previewSelection() {
        if (!this.videoReady) return

        this.previewSelectionActive = true
        this.videoPlayerTarget.currentTime = Number.parseFloat(this.startTimeTarget.value || "0")

        try {
            await this.videoPlayerTarget.play()
            this.setStatus(this.loopPreviewEnabled ? "Loop preview active" : "Previewing selection", "ready")
        } catch (error) {
            this.handleFailure(error, "The browser blocked playback. Interact with the player once, then preview again.")
        }
    }

    toggleLoopPreview() {
        this.loopPreviewEnabled = !this.loopPreviewEnabled
        this.updateLoopUi()
        this.commitState(this.loopPreviewEnabled ? "Loop preview on" : "Loop preview off")
    }

    updateLoopUi() {
        if (!this.hasLoopToggleTarget) return

        this.loopToggleTarget.textContent = this.loopPreviewEnabled ? "Loop Preview On" : "Loop Preview Off"
        this.loopToggleTarget.classList.toggle("active", this.loopPreviewEnabled)
    }

    maintainSelectionPlayback() {
        if (!this.videoReady) return

        const start = Number.parseFloat(this.startTimeTarget.value || "0")
        const end = Number.parseFloat(this.endTimeTarget.value || "0")
        if (this.videoPlayerTarget.currentTime < end - 0.05) return

        if (this.loopPreviewEnabled) {
            this.videoPlayerTarget.currentTime = start
            if (this.videoPlayerTarget.paused) this.videoPlayerTarget.play().catch(() => { })
            return
        }

        if (this.previewSelectionActive) {
            this.videoPlayerTarget.pause()
            this.videoPlayerTarget.currentTime = end
            this.previewSelectionActive = false
        }
    }

    togglePlayback() {
        if (this.videoPlayerTarget.paused) {
            this.videoPlayerTarget.play().catch(() => { })
        } else {
            this.videoPlayerTarget.pause()
        }
    }

    markInPoint() {
        const end = Number.parseFloat(this.endTimeTarget.value || "0")
        this.setRange(this.videoPlayerTarget.currentTime, end, { commit: true, statusText: "In point updated" })
    }

    markOutPoint() {
        const start = Number.parseFloat(this.startTimeTarget.value || "0")
        this.setRange(start, this.videoPlayerTarget.currentTime, { commit: true, statusText: "Out point updated" })
    }

    applyTextTemplate(event) {
        const templateText = event.currentTarget.dataset.templateText || ""
        const templateStyle = event.currentTarget.dataset.templateStyle || this.textStyleTarget.value

        this.textOverlayTarget.value = templateText
        this.textStyleTarget.value = templateStyle
        this.refreshPreview()
        this.commitState("Text template applied")
    }

    handleKeydown(event) {
        if (event.defaultPrevented) return

        const target = event.target
        if (target instanceof HTMLElement && target.closest("input, textarea, select, button, [contenteditable='true']")) {
            return
        }

        const key = event.key.toLowerCase()

        if ((event.metaKey || event.ctrlKey) && key === "z") {
            event.preventDefault()
            if (event.shiftKey) {
                this.redo()
            } else {
                this.undo()
            }
            return
        }

        if ((event.metaKey || event.ctrlKey) && key === "y") {
            event.preventDefault()
            this.redo()
            return
        }

        if (event.metaKey || event.ctrlKey || event.altKey) return

        if (key === " ") {
            event.preventDefault()
            this.togglePlayback()
            return
        }

        if (!this.videoReady) return

        if (key === "i") {
            event.preventDefault()
            this.markInPoint()
        } else if (key === "o") {
            event.preventDefault()
            this.markOutPoint()
        } else if (key === "s") {
            event.preventDefault()
            this.addSegment()
        } else if (key === "l") {
            event.preventDefault()
            this.toggleLoopPreview()
        }
    }

    undo() {
        if (this.historyIndex <= 0) return

        this.historyIndex -= 1
        this.applyState(this.history[this.historyIndex].state)
        this.scheduleAutosave()
        this.syncHistoryButtons()
        this.setStatus("Undid last edit", "ready")
    }

    redo() {
        if (this.historyIndex >= this.history.length - 1) return

        this.historyIndex += 1
        this.applyState(this.history[this.historyIndex].state)
        this.scheduleAutosave()
        this.syncHistoryButtons()
        this.setStatus("Restored edit", "ready")
    }

    pushHistory(options = {}) {
        const { force = false, silent = false } = options
        if (this.restoringState) return

        const state = this.snapshotState()
        const hash = JSON.stringify(state)
        const current = this.history[this.historyIndex]

        if (!force && current && current.hash === hash) {
            this.syncHistoryButtons()
            return
        }

        this.history = this.history.slice(0, this.historyIndex + 1)
        this.history.push({ hash, state })

        if (this.history.length > 60) {
            this.history.shift()
        }

        this.historyIndex = this.history.length - 1
        this.syncHistoryButtons()
        if (!silent) this.scheduleAutosave()
    }

    syncHistoryButtons() {
        if (this.hasUndoBtnTarget) this.undoBtnTarget.disabled = this.historyIndex <= 0
        if (this.hasRedoBtnTarget) this.redoBtnTarget.disabled = this.historyIndex >= this.history.length - 1 || this.history.length === 0
    }

    commitState(text) {
        this.pushHistory()
        this.setStatus(text, "ready")
    }

    snapshotState() {
        return {
            startTime: this.startTimeTarget.value,
            endTime: this.endTimeTarget.value,
            format: this.formatTarget.value,
            fitMode: this.fitModeTarget.value,
            compression: this.compressionTarget.value,
            textOverlay: this.textOverlayTarget.value,
            textPosition: this.textPositionTarget.value,
            textStyle: this.textStyleTarget.value,
            textSize: this.textSizeTarget.value,
            audioMode: this.audioModeTarget.value,
            audioSource: this.audioSourceTarget.value,
            audioUrl: this.audioUrlTarget.value.trim(),
            effectPreset: this.effectPresetTarget.value,
            brightness: this.brightnessTarget.value,
            contrast: this.contrastTarget.value,
            saturation: this.saturationTarget.value,
            warmth: this.warmthTarget.value,
            blur: this.blurTarget.value,
            transition: this.transitionTarget.value,
            transitionDuration: this.transitionDurationTarget.value,
            exportName: this.exportNameTarget.value,
            originalVolume: this.originalVolumeTarget.value,
            musicVolume: this.musicVolumeTarget.value,
            musicFadeIn: this.musicFadeInTarget.value,
            musicFadeOut: this.musicFadeOutTarget.value,
            loopPreviewEnabled: this.loopPreviewEnabled,
            segments: this.segments.map((segment) => ({
                id: segment.id,
                title: segment.title,
                start: segment.start,
                end: segment.end,
                duration: segment.duration
            }))
        }
    }

    applyState(state) {
        if (!state) return

        this.restoringState = true

        this.startTimeTarget.value = state.startTime ?? this.startTimeTarget.value
        this.endTimeTarget.value = state.endTime ?? this.endTimeTarget.value
        this.formatTarget.value = state.format ?? this.formatTarget.value
        this.fitModeTarget.value = state.fitMode ?? this.fitModeTarget.value
        this.compressionTarget.value = state.compression ?? this.compressionTarget.value
        this.textOverlayTarget.value = state.textOverlay ?? this.textOverlayTarget.value
        this.textPositionTarget.value = state.textPosition ?? this.textPositionTarget.value
        this.textStyleTarget.value = state.textStyle ?? this.textStyleTarget.value
        this.textSizeTarget.value = state.textSize ?? this.textSizeTarget.value
        this.audioModeTarget.value = state.audioMode ?? this.audioModeTarget.value
        this.audioSourceTarget.value = state.audioSource ?? this.audioSourceTarget.value
        this.audioUrlTarget.value = state.audioUrl ?? this.audioUrlTarget.value
        this.effectPresetTarget.value = state.effectPreset ?? this.effectPresetTarget.value
        this.brightnessTarget.value = state.brightness ?? this.brightnessTarget.value
        this.contrastTarget.value = state.contrast ?? this.contrastTarget.value
        this.saturationTarget.value = state.saturation ?? this.saturationTarget.value
        this.warmthTarget.value = state.warmth ?? this.warmthTarget.value
        this.blurTarget.value = state.blur ?? this.blurTarget.value
        this.transitionTarget.value = state.transition ?? this.transitionTarget.value
        this.transitionDurationTarget.value = state.transitionDuration ?? this.transitionDurationTarget.value
        this.exportNameTarget.value = state.exportName ?? this.exportNameTarget.value
        this.originalVolumeTarget.value = state.originalVolume ?? this.originalVolumeTarget.value
        this.musicVolumeTarget.value = state.musicVolume ?? this.musicVolumeTarget.value
        this.musicFadeInTarget.value = state.musicFadeIn ?? this.musicFadeInTarget.value
        this.musicFadeOutTarget.value = state.musicFadeOut ?? this.musicFadeOutTarget.value
        this.loopPreviewEnabled = Boolean(state.loopPreviewEnabled)
        this.segments = Array.isArray(state.segments) ? state.segments.map((segment, index) => ({
            id: segment.id || `${index}-${Date.now()}`,
            title: segment.title || `Clip ${index + 1}`,
            start: Number.parseFloat(segment.start || 0),
            end: Number.parseFloat(segment.end || 1),
            duration: Math.max(1, Number.parseFloat(segment.duration || ((segment.end || 1) - (segment.start || 0))))
        })) : []

        if (this.videoReady) this.clampSegmentsToDuration(this.videoPlayerTarget.duration)

        this.restoringState = false
        this.toggleAudioInputs()
        this.updateTransitionLabel()
        this.updateLoopUi()
        this.updateDownloadFileName("mp4")
        this.renderSegments()
        this.refreshPreview()
        if (this.videoReady) this.updateTimer()
        this.syncHistoryButtons()
    }

    storageKey() {
        return `ffmpeg-studio:${this.articleIdValue}`
    }

    scheduleAutosave() {
        if (this.restoringState || !this.hasAutosaveStatusTarget) return

        if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
        this.updateAutosaveStatus("Saving draft...", "saving")
        this.autosaveTimer = window.setTimeout(() => this.persistDraft(), 220)
    }

    persistDraft() {
        try {
            window.localStorage.setItem(this.storageKey(), JSON.stringify(this.snapshotState()))
            this.updateAutosaveStatus("Draft saved", "saved")
        } catch (_error) {
            this.updateAutosaveStatus("Autosave unavailable", "error")
        }
    }

    restoreSavedState() {
        this.updateAutosaveStatus("Autosave ready", "idle")

        try {
            const raw = window.localStorage.getItem(this.storageKey())
            if (!raw) return

            const state = JSON.parse(raw)
            this.applyState(state)
            this.updateAutosaveStatus("Draft restored", "saved")
        } catch (_error) {
            this.updateAutosaveStatus("Autosave unavailable", "error")
        }
    }

    clearAutosave() {
        try {
            window.localStorage.removeItem(this.storageKey())
            this.updateAutosaveStatus("Saved draft cleared", "idle")
            this.setStatus("Saved draft cleared", "ready")
        } catch (_error) {
            this.updateAutosaveStatus("Autosave unavailable", "error")
        }
    }

    updateAutosaveStatus(text, state) {
        if (!this.hasAutosaveStatusTarget) return

        this.autosaveStatusTarget.textContent = text
        this.autosaveStatusTarget.dataset.state = state
    }

    safeExportBaseName() {
        const fallback = `vital-veggies-short-${this.articleIdValue}`
        const normalized = (this.exportNameTarget.value || fallback)
            .trim()
            .normalize("NFKD")
            .replace(/[^\w\s-]/g, "")
            .replace(/[\s_-]+/g, "-")
            .replace(/^-+|-+$/g, "")
            .toLowerCase()
            .slice(0, 64)

        return normalized || fallback
    }

    updateDownloadFileName(extension) {
        this.downloadBtnTarget.download = `${this.safeExportBaseName()}.${extension}`
    }

    clampSegmentsToDuration(duration) {
        if (!Number.isFinite(duration) || duration <= 0) return

        this.segments = this.segments.map((segment, index) => {
            const start = Math.max(0, Math.min(Number.parseFloat(segment.start || 0), duration))
            const end = Math.max(start + 1, Math.min(Number.parseFloat(segment.end || duration), duration))
            return {
                id: segment.id || `${index}-${Date.now()}`,
                title: segment.title || `Clip ${index + 1}`,
                start,
                end,
                duration: Math.max(1, end - start)
            }
        })
    }

    originalAudioGain() {
        return Number(this.originalVolumeTarget.value || 0) / 100
    }

    musicAudioGain() {
        return Number(this.musicVolumeTarget.value || 0) / 100
    }

    musicFadeInSeconds() {
        return Math.max(0, Number(this.musicFadeInTarget.value || 0))
    }

    musicFadeOutSeconds() {
        return Math.max(0, Number(this.musicFadeOutTarget.value || 0))
    }

    async exportFrame() {
        if (!this.videoReady) return

        const dimensions = this.outputDimensions(this.formatTarget.value)
        const canvas = document.createElement("canvas")
        const context = canvas.getContext("2d")

        canvas.width = dimensions.width
        canvas.height = dimensions.height

        context.fillStyle = "#0b1220"
        context.fillRect(0, 0, canvas.width, canvas.height)
        context.filter = this.previewFilterString()

        const frame = this.calculateFrameRect(dimensions, this.fitModeTarget.value === "crop")
        context.drawImage(this.videoPlayerTarget, frame.x, frame.y, frame.width, frame.height)
        context.filter = "none"

        if (this.textOverlayTarget.value.trim()) {
            this.drawCanvasCaption(context, canvas.width, canvas.height, dimensions, this.textOverlayTarget.value.trim())
        }

        const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
        const url = URL.createObjectURL(blob)
        const link = document.createElement("a")
        link.href = url
        link.download = `${this.safeExportBaseName()}-cover.png`
        link.click()
        URL.revokeObjectURL(url)

        this.setStatus("Cover frame downloaded", "ready")
    }

    calculateFrameRect(dimensions, cropMode) {
        const videoWidth = this.videoPlayerTarget.videoWidth || 1280
        const videoHeight = this.videoPlayerTarget.videoHeight || 720
        const scale = cropMode
            ? Math.max(dimensions.width / videoWidth, dimensions.height / videoHeight)
            : Math.min(dimensions.width / videoWidth, dimensions.height / videoHeight)

        const width = videoWidth * scale
        const height = videoHeight * scale

        return {
            x: (dimensions.width - width) / 2,
            y: (dimensions.height - height) / 2,
            width,
            height
        }
    }

    drawCanvasCaption(context, width, height, dimensions, text) {
        const caption = this.truncateText(text, 54)
        const appearance = this.captionAppearance(dimensions)
        const fontSize = appearance.fontSize
        const boxWidth = Math.min(width - 80, Math.max(260, fontSize * caption.length * 0.68))
        const boxHeight = fontSize + appearance.paddingY
        const x = (width - boxWidth) / 2
        const y = this.captionBoxY(height, boxHeight, dimensions)

        context.save()
        context.fillStyle = appearance.background
        this.roundRect(context, x, y, boxWidth, boxHeight, appearance.radius)
        context.fill()
        if (appearance.borderColor) {
            context.lineWidth = appearance.radius === 999 ? 2 : 1.4
            context.strokeStyle = appearance.borderColor
            context.stroke()
        }
        context.fillStyle = appearance.color
        context.font = `${appearance.fontWeight} ${fontSize}px ${appearance.fontFamily}`
        context.textAlign = "center"
        context.textBaseline = "middle"
        if (appearance.textShadow) {
            context.shadowColor = appearance.borderColor || "rgba(255,255,255,0.18)"
            context.shadowBlur = 18
        }
        context.fillText(caption, width / 2, y + (boxHeight / 2))
        context.restore()
    }

    captionBoxY(height, boxHeight, dimensions) {
        switch (this.textPositionTarget.value) {
            case "top":
                return dimensions.overlayBottom
            case "center":
                return (height - boxHeight) / 2
            default:
                return height - boxHeight - dimensions.overlayBottom
        }
    }

    async generate() {
        if (!this.videoReady) return

        try {
            await this.ensureFfmpegLoaded({ interactive: true })
        } catch (_error) {
            return
        }

        try {
            this.hideError()
            this.setGenerateDisabled(true)
            this.outputSectionTarget.classList.add("hidden")
            this.showOverlay("Fetching original video...", 16)
            this.setStatus("Fetching source", "busy")

            const inputName = `input-${this.articleIdValue}.mp4`
            const outputName = `short-${this.articleIdValue}.mp4`
            const segments = this.activeSegments().map((segment, index) => ({
                ...segment,
                title: segment.title || `Clip ${index + 1}`,
                duration: Math.max(1, segment.end - segment.start)
            }))

            let musicInputName = null
            let overlayName = null
            let nextInputIndex = 1
            let musicInputIndex = null
            let overlayInputIndex = null

            this.ffmpegLogs = []
            this.cleanupFile(inputName)
            this.cleanupFile(outputName)

            const videoData = await this.fetchVideoBytes()
            this.ffmpeg.FS("writeFile", inputName, videoData)

            const args = ["-i", inputName]

            if (this.audioModeTarget.value === "music") {
                musicInputName = await this.writeMusicFile()
                musicInputIndex = nextInputIndex
                args.push("-stream_loop", "-1", "-i", musicInputName)
                nextInputIndex += 1
            }

            if (this.textOverlayTarget.value.trim()) {
                overlayName = await this.writeTextOverlayImage(this.textOverlayTarget.value.trim(), this.formatTarget.value)
                overlayInputIndex = nextInputIndex
                args.push("-i", overlayName)
                nextInputIndex += 1
            }

            this.updateProgress("Assembling timeline...", 34)

            const graphConfig = this.buildFilterGraph(segments, {
                format: this.formatTarget.value,
                overlayInputIndex,
                musicInputIndex,
                musicMode: this.audioModeTarget.value === "music",
                keepSourceAudio: this.audioModeTarget.value !== "mute" && this.sourceHasAudio && this.originalAudioGain() > 0,
                sourceAudioGain: this.originalAudioGain(),
                musicGain: this.musicAudioGain(),
                musicFadeIn: this.musicFadeInSeconds(),
                musicFadeOut: this.musicFadeOutSeconds()
            })

            const settings = this.compressionSettings()
            args.push(
                "-t", graphConfig.totalDuration.toFixed(2),
                "-filter_complex", graphConfig.graph,
                "-map", graphConfig.videoLabel,
                "-c:v", "libx264",
                "-preset", "ultrafast",
                "-crf", settings.crf,
                "-maxrate", settings.maxrate,
                "-bufsize", settings.bufsize,
                "-pix_fmt", "yuv420p",
                "-movflags", "faststart"
            )

            if (graphConfig.audioLabel) {
                args.push("-map", graphConfig.audioLabel, "-c:a", "aac", "-b:a", "128k")
            } else {
                args.push("-an")
            }

            args.push(outputName)

            await this.ffmpeg.run(...args)

            if (!this.fileExists(outputName)) {
                throw new Error(`FFmpeg finished without creating ${outputName}. ${this.lastFfmpegLog()}`)
            }

            this.updateProgress("Finalizing download...", 94)

            const data = this.ffmpeg.FS("readFile", outputName)
            const buffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength)
            const url = URL.createObjectURL(new Blob([buffer], { type: "video/mp4" }))

            if (this.generatedUrl) URL.revokeObjectURL(this.generatedUrl)
            this.generatedUrl = url
            this.outputVideoTarget.src = url
            this.downloadBtnTarget.href = url
            this.updateDownloadFileName("mp4")
            this.outputSectionTarget.classList.remove("hidden")

            this.setStatus("Short generated", "ready")
            this.updateProgress("Short video ready.", 100)
            window.setTimeout(() => this.hideOverlay(), 350)
        } catch (error) {
            this.handleFailure(error, "The studio could not fetch or process the source media. Reduce the sequence size, use smaller compression, or remove heavy layers and try again.")
        } finally {
            this.setGenerateDisabled(!this.videoReady)
        }
    }

    buildFilterGraph(segments, options) {
        const dimensions = this.outputDimensions(options.format)
        const graph = []

        const speed = this.hasPlaybackSpeedTarget ? (Number(this.playbackSpeedTarget.value) || 1.0) : 1.0
        const durations = segments.map((segment) => Math.max(1, segment.duration / speed))

        const speedVideoFilter = speed !== 1.0 ? `,setpts=${1 / speed}*PTS` : ""
        let speedAudioFilter = ""
        if (speed !== 1.0) {
            let tempSpeed = speed
            const atempos = []
            while (tempSpeed < 0.5) {
                atempos.push("atempo=0.5")
                tempSpeed /= 0.5
            }
            if (tempSpeed !== 1.0) atempos.push(`atempo=${tempSpeed.toFixed(3)}`)
            speedAudioFilter = `,${atempos.join(",")}`
        }

        segments.forEach((segment, index) => {
            graph.push(
                `[0:v]trim=start=${segment.start}:end=${segment.end},setpts=PTS-STARTPTS${speedVideoFilter},${this.videoProcessingChain(dimensions)}[v${index}]`
            )

            if (options.keepSourceAudio) {
                graph.push(
                    `[0:a]atrim=start=${segment.start}:end=${segment.end},asetpts=PTS-STARTPTS${speedAudioFilter}[a${index}]`
                )
            }
        })

        let videoBaseLabel = "v0"
        let audioBaseLabel = options.keepSourceAudio ? "a0" : null
        let totalDuration = durations[0]

        if (segments.length > 1) {
            if (this.transitionTarget.value === "none") {
                if (options.keepSourceAudio) {
                    const inputs = segments.map((_, index) => `[v${index}][a${index}]`).join("")
                    graph.push(`${inputs}concat=n=${segments.length}:v=1:a=1[vcat][acat]`)
                    videoBaseLabel = "vcat"
                    audioBaseLabel = "acat"
                } else {
                    const inputs = segments.map((_, index) => `[v${index}]`).join("")
                    graph.push(`${inputs}concat=n=${segments.length}:v=1:a=0[vcat]`)
                    videoBaseLabel = "vcat"
                    audioBaseLabel = null
                }
                totalDuration = durations.reduce((sum, value) => sum + value, 0)
            } else {
                let currentVideo = "v0"
                let currentAudio = options.keepSourceAudio ? "a0" : null
                totalDuration = durations[0]

                segments.slice(1).forEach((segment, offsetIndex) => {
                    const index = offsetIndex + 1
                    const duration = this.safeTransitionDuration(totalDuration, durations[index])
                    const transition = this.transitionTarget.value
                    const videoLabel = `vx${index}`
                    const audioLabel = options.keepSourceAudio ? `ax${index}` : null
                    const xfadeOffset = Math.max(0.05, totalDuration - duration)

                    graph.push(
                        `[${currentVideo}][v${index}]xfade=transition=${transition}:duration=${duration.toFixed(2)}:offset=${xfadeOffset.toFixed(2)}[${videoLabel}]`
                    )

                    if (options.keepSourceAudio) {
                        graph.push(
                            `[${currentAudio}][a${index}]acrossfade=d=${duration.toFixed(2)}:c1=tri:c2=tri[${audioLabel}]`
                        )
                    }

                    currentVideo = videoLabel
                    currentAudio = audioLabel
                    totalDuration = totalDuration + durations[index] - duration
                })

                videoBaseLabel = currentVideo
                audioBaseLabel = currentAudio
            }
        }

        if (audioBaseLabel && options.sourceAudioGain < 0.99) {
            graph.push(`[${audioBaseLabel}]volume=${Math.max(0, options.sourceAudioGain).toFixed(2)}[asource]`)
            audioBaseLabel = "asource"
        }

        let finalVideoLabel = videoBaseLabel
        if (options.overlayInputIndex !== null && options.overlayInputIndex !== undefined) {
            graph.push(
                `[${videoBaseLabel}][${options.overlayInputIndex}:v]overlay=(W-w)/2:${this.overlayYExpression(dimensions)}[vfinal]`
            )
            finalVideoLabel = "vfinal"
        }

        if (options.musicMode && options.musicInputIndex !== null) {
            let musicChain = `[${options.musicInputIndex}:a]atrim=0:${totalDuration.toFixed(2)},asetpts=PTS-STARTPTS`

            if (options.musicFadeIn > 0) {
                musicChain += `,afade=t=in:st=0:d=${options.musicFadeIn.toFixed(2)}`
            }

            if (options.musicFadeOut > 0 && totalDuration > 0.25) {
                const fadeOutDuration = Math.min(options.musicFadeOut, Math.max(0.15, totalDuration - 0.05))
                const fadeOutStart = Math.max(0, totalDuration - fadeOutDuration)
                musicChain += `,afade=t=out:st=${fadeOutStart.toFixed(2)}:d=${fadeOutDuration.toFixed(2)}`
            }

            musicChain += `,volume=${Math.max(0, options.musicGain).toFixed(2)}[amusic]`
            graph.push(musicChain)

            if (audioBaseLabel) {
                graph.push(`[${audioBaseLabel}][amusic]amix=inputs=2:duration=first:dropout_transition=2[aout]`)
                audioBaseLabel = "aout"
            } else {
                audioBaseLabel = "amusic"
            }
        }

        return {
            graph: graph.join(";"),
            videoLabel: `[${finalVideoLabel}]`,
            audioLabel: audioBaseLabel ? `[${audioBaseLabel}]` : null,
            totalDuration
        }
    }

    overlayYExpression(dimensions) {
        switch (this.textPositionTarget.value) {
            case "top":
                return `${dimensions.overlayBottom}`
            case "center":
                return "(H-h)/2"
            default:
                return `H-h-${dimensions.overlayBottom}`
        }
    }

    safeTransitionDuration(previousDuration, nextDuration) {
        const requested = this.transitionSeconds()
        return Math.max(0.15, Math.min(requested, previousDuration - 0.05, nextDuration - 0.05))
    }

    videoProcessingChain(dimensions) {
        const state = this.visualState()

        let scaleCropFilter = ""
        if (this.fitModeTarget.value === "crop") {
            scaleCropFilter = `scale=${dimensions.width}:${dimensions.height}:force_original_aspect_ratio=increase,crop=${dimensions.width}:${dimensions.height}`
        } else {
            scaleCropFilter = `scale=${dimensions.width}:${dimensions.height}:force_original_aspect_ratio=decrease,pad=${dimensions.width}:${dimensions.height}:(ow-iw)/2:(oh-ih)/2:color=0x0b1220`
        }

        const zoom = this.hasZoomTarget ? (Number(this.zoomTarget.value) || 1.0) : 1.0
        const offX = this.hasOffsetXTarget ? (Number(this.offsetXTarget.value) || 0) : 0
        const offY = this.hasOffsetYTarget ? (Number(this.offsetYTarget.value) || 0) : 0

        if (zoom !== 1.0 || offX !== 0 || offY !== 0) {
            const cropW = dimensions.width
            const cropH = dimensions.height
            // Crop offsets centering based on slider percentage.
            scaleCropFilter += `,scale=${dimensions.width}*${zoom}:-2,crop=${cropW}:${cropH}:((in_w-${cropW})/2)-((in_w-${cropW})/2)*(${offX}/100):((in_h-${cropH})/2)-((in_h-${cropH})/2)*(${offY}/100)`
        }

        const filters = [scaleCropFilter]

        filters.push(
            `eq=brightness=${(state.brightness * 0.35).toFixed(3)}:contrast=${Math.max(0.45, 1 + state.contrast).toFixed(3)}:saturation=${Math.max(0, state.grayscale ? 0 : 1 + state.saturation).toFixed(3)}`
        )

        if (state.grayscale) filters.push("hue=s=0")

        if (Math.abs(state.warmth) > 0.01) {
            const warmth = (state.warmth / 2.5).toFixed(3)
            const cool = (-state.warmth / 2.5).toFixed(3)
            filters.push(`colorbalance=rs=${warmth}:gs=${(state.warmth / 5).toFixed(3)}:bs=${cool}`)
        }

        if (state.blur > 0.1) filters.push(`gblur=sigma=${Math.min(4, state.blur).toFixed(2)}`)

        filters.push("format=yuv420p", "setsar=1")
        return filters.join(",")
    }

    outputDimensions(format) {
        if (format === "1:1") return { width: 720, height: 720, font: 34, overlayBottom: 48 }
        if (format === "16:9") return { width: 1280, height: 720, font: 30, overlayBottom: 36 }

        return { width: 720, height: 1280, font: 40, overlayBottom: 72 }
    }

    compressionSettings() {
        if (this.compressionTarget.value === "small") {
            return { crf: "34", maxrate: "1200k", bufsize: "2400k" }
        }

        if (this.compressionTarget.value === "premium") {
            return { crf: "24", maxrate: "4200k", bufsize: "8400k" }
        }

        return { crf: "29", maxrate: "2200k", bufsize: "4400k" }
    }

    async fetchVideoBytes() {
        const videoUrl = new URL(this.videoUrlValue, window.location.origin)
        const response = await fetch(videoUrl, {
            credentials: "same-origin",
            cache: "no-store",
            headers: { Accept: "video/*,*/*" }
        })

        if (!response.ok) {
            throw new Error(`Video fetch failed (${response.status} ${response.statusText})`)
        }

        const contentType = response.headers.get("content-type") || ""
        if (!contentType.includes("video") && !contentType.includes("octet-stream")) {
            throw new Error(`Unexpected video response type: ${contentType || "unknown"}`)
        }

        const buffer = await response.arrayBuffer()
        if (buffer.byteLength === 0) throw new Error("The source video is empty.")

        return new Uint8Array(buffer)
    }

    async writeMusicFile() {
        if (this.audioSourceTarget.value === "online") {
            return this.writeOnlineMusicFile()
        }

        const file = this.audioInputTarget.files[0]
        if (!file) {
            throw new Error("Choose an audio file from your system or switch music source to online URL.")
        }

        const buffer = await file.arrayBuffer()
        if (buffer.byteLength === 0) throw new Error("The selected audio file is empty.")

        const extension = file.name.split(".").pop() || "audio"
        const name = `music-${this.articleIdValue}.${extension}`
        this.cleanupFile(name)
        this.ffmpeg.FS("writeFile", name, new Uint8Array(buffer))
        return name
    }

    async writeOnlineMusicFile() {
        const audioUrl = this.audioUrlTarget.value.trim()
        if (!audioUrl) {
            throw new Error("Paste a direct online audio URL or switch music source to system upload.")
        }

        let parsedUrl
        try {
            parsedUrl = new URL(audioUrl)
        } catch (_error) {
            throw new Error("The online audio URL is not valid.")
        }

        if (!["http:", "https:"].includes(parsedUrl.protocol)) {
            throw new Error("Online audio URL must start with http:// or https://.")
        }

        const proxyUrl = new URL(this.audioProxyUrlValue, window.location.origin)
        proxyUrl.searchParams.set("url", parsedUrl.toString())

        this.updateProgress("Fetching background music...", 24)

        const response = await fetch(proxyUrl, {
            credentials: "same-origin",
            cache: "no-store",
            headers: { Accept: "audio/*,*/*" }
        })

        if (!response.ok) {
            const message = await response.text()
            throw new Error(`Online audio fetch failed (${response.status}). ${message}`)
        }

        const contentType = response.headers.get("content-type") || ""
        if (!contentType.includes("audio") && !contentType.includes("octet-stream")) {
            throw new Error(`Online URL did not return audio. Response type: ${contentType || "unknown"}`)
        }

        const buffer = await response.arrayBuffer()
        if (buffer.byteLength === 0) throw new Error("The online audio file is empty.")

        const name = `music-${this.articleIdValue}${this.extensionForAudio(contentType, parsedUrl.pathname)}`
        this.cleanupFile(name)
        this.ffmpeg.FS("writeFile", name, new Uint8Array(buffer))
        return name
    }

    async writeTextOverlayImage(text, format) {
        const dimensions = this.outputDimensions(format)
        const appearance = this.captionAppearance(dimensions)
        const width = Math.min(dimensions.width - 72, 860)
        const height = Math.round(appearance.fontSize + appearance.paddingY)
        const canvas = document.createElement("canvas")
        const context = canvas.getContext("2d")
        const name = `text-overlay-${this.articleIdValue}.png`

        canvas.width = width
        canvas.height = height

        context.fillStyle = appearance.background
        this.roundRect(context, 0, 0, width, height, appearance.radius)
        context.fill()
        if (appearance.borderColor) {
            context.lineWidth = appearance.radius === 999 ? 2 : 1.4
            context.strokeStyle = appearance.borderColor
            context.stroke()
        }

        context.fillStyle = appearance.color
        context.textAlign = "center"
        context.textBaseline = "middle"
        context.font = `${appearance.fontWeight} ${appearance.fontSize}px ${appearance.fontFamily}`
        if (appearance.textShadow) {
            context.shadowColor = appearance.borderColor || "rgba(255,255,255,0.18)"
            context.shadowBlur = 18
        }
        context.fillText(this.truncateText(text, 54), width / 2, height / 2)

        const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
        const buffer = await blob.arrayBuffer()

        this.cleanupFile(name)
        this.ffmpeg.FS("writeFile", name, new Uint8Array(buffer))
        return name
    }

    extensionForAudio(contentType, pathname) {
        const pathExtension = pathname.match(/\.[a-z0-9]{2,5}$/i)?.[0]
        if (pathExtension) return pathExtension
        if (contentType.includes("mpeg")) return ".mp3"
        if (contentType.includes("wav")) return ".wav"
        if (contentType.includes("ogg")) return ".ogg"
        if (contentType.includes("mp4") || contentType.includes("aac")) return ".m4a"

        return ".audio"
    }

    roundRect(context, x, y, width, height, radius) {
        context.beginPath()
        context.moveTo(x + radius, y)
        context.arcTo(x + width, y, x + width, y + height, radius)
        context.arcTo(x + width, y + height, x, y + height, radius)
        context.arcTo(x, y + height, x, y, radius)
        context.arcTo(x, y, x + width, y, radius)
        context.closePath()
    }

    truncateText(text, maxLength) {
        return text.length > maxLength ? `${text.slice(0, maxLength - 1)}...` : text
    }

    cleanupFile(name) {
        if (!name) return

        try {
            this.ffmpeg.FS("unlink", name)
        } catch (_error) {
            // Ignore missing file cleanup.
        }
    }

    fileExists(name) {
        try {
            this.ffmpeg.FS("stat", name)
            return true
        } catch (_error) {
            return false
        }
    }

    lastFfmpegLog() {
        return this.ffmpegLogs.slice(-14).join(" ") || "No FFmpeg diagnostic output was captured."
    }

    setGenerateDisabled(disabled) {
        this.generateBtnTarget.disabled = disabled
    }

    showOverlay(text, percent) {
        this.overlayTarget.classList.remove("hidden")
        this.updateProgress(text, percent)
    }

    hideOverlay() {
        this.overlayTarget.classList.add("hidden")
    }

    updateProgress(text, percent) {
        this.progressTextTarget.textContent = text
        this.progressBarTarget.style.width = `${percent}%`
    }

    setStatus(text, state) {
        this.statusTarget.textContent = text
        this.statusTarget.dataset.state = state
    }

    showError(message) {
        this.errorTextTarget.textContent = message
        this.errorPanelTarget.classList.remove("hidden")
    }

    hideError() {
        this.errorPanelTarget.classList.add("hidden")
        this.errorTextTarget.textContent = ""
    }

    handleFailure(error, fallbackMessage) {
        console.error("FFmpeg Studio Error:", error)
        this.hideOverlay()
        this.setStatus("Action failed", "error")
        this.showError(`${fallbackMessage} Details: ${error.message}`)
    }
}
