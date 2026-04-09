<template>
  <div ref="container" class="container">
    <iframe id="vncFrame" ref="vncFrame" class="frame" frameBorder="0" v-show="true" scrolling="no"></iframe>
  </div>
</template>

<script>

export default {
  name: 'Vnc',
  components: {
  },
  data () {
    return {
      vncState: 'stopped',
      config: {
        mode: 'vnc'
      },
      stateID: -1,
      errorMessage: '',
      width: 0,
      height: 0,
      fixedResolution: false,
      resizeMode: 'scale',
      resizeObserver: null,
      resizeDebounceTimer: null,
      stateErrorCount: 0,
      timerState: null
    }
  },
  created: function () {
    window.addEventListener('message', this.onMessage)
  },
  mounted: function () {
    this.setupResizeObserver()
    this.update_status()
  },
  beforeDestroy: function () {
    clearTimeout(this.timerState)
    clearTimeout(this.resizeDebounceTimer)
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    window.removeEventListener('message', this.onMessage)
  },
  methods: {
    getViewportSize: function () {
      const container = this.$refs.container
      const frame = this.$refs.vncFrame
      const width = Math.max(
        Math.round((container && container.clientWidth) || (frame && frame.clientWidth) || window.innerWidth || 0),
        1
      )
      const height = Math.max(
        Math.round((container && container.clientHeight) || (frame && frame.clientHeight) || window.innerHeight || 0),
        1
      )
      return {
        w: width,
        h: height
      }
    },
    getDesiredResizeMode: function () {
      const viewport = this.getViewportSize()
      if (this.fixedResolution) {
        return 'scale'
      }
      if (viewport.w < 640 || viewport.h < 480) {
        return 'scale'
      }
      return 'remote'
    },
    setupResizeObserver: function () {
      if (!window.ResizeObserver || !this.$refs.container) {
        return
      }
      this.resizeObserver = new window.ResizeObserver(() => {
        this.scheduleRemoteResize()
      })
      this.resizeObserver.observe(this.$refs.container)
    },
    scheduleRemoteResize: function () {
      clearTimeout(this.resizeDebounceTimer)
      this.resizeDebounceTimer = setTimeout(() => {
        this.resizeDebounceTimer = null
        this.applyResizeMode()
      }, 250)
    },
    applyResizeMode: function () {
      this.setResizeMode(this.getDesiredResizeMode())
    },
    setResizeMode: function (mode) {
      this.resizeMode = mode
      if (this.$refs.vncFrame && this.$refs.vncFrame.contentWindow) {
        this.$refs.vncFrame.contentWindow.postMessage(JSON.stringify({
          from: 'parent',
          type: 'setResizeMode',
          mode: mode
        }), '*')
      }
    },
    update_status: async function () {
      const viewport = this.getViewportSize()
      const params = {
        'id': this.stateID,
        'w': viewport.w,
        'h': viewport.h
      }
      try {
        const response = await this.$http.get('api/state', { params: params })
        const body = response.data
        if (body.code !== 200) {
          this.stateErrorCount += 1
          if (this.stateErrorCount > 10) {
            this.errorMessage = this.translate('serviceIsUnavailable', 'Service is unavailable')
            throw this.errorMessage
          }
        }

        this.stateID = body.data.id
        this.width = body.data.width || 0
        this.height = body.data.height || 0
        this.fixedResolution = body.data.config.fixedResolution
        this.applyResizeMode()

        if (this.vncState === 'stopped') {
          this.reconnect(false)
        }

        this.schedule_next_update_status()
      } catch (error) {
        this.stateErrorCount += 1
        if (this.stateErrorCount > 10) {
          this.errorMessage = this.translate('serviceIsUnavailable', 'Service is unavailable')
        } else {
          this.schedule_next_update_status()
        }
      }
    },
    schedule_next_update_status: function (afterMseconds = 1000) {
      if (this.timerState !== null) {
        return
      }
      this.timerState = setTimeout(() => {
        this.timerState = null
        this.update_status()
      }, afterMseconds)
    },
    reconnect: function (force = false) {
      console.log('connecting...')
      this.errorMessage = ''
      let websockifyPath = location.pathname.substr(1) + 'websockify'
      if (force || this.vncState === 'stopped') {
        this.vncState = 'connecting'
        let hostname = window.location.hostname
        let port = window.location.port
        if (!port) {
          port = window.location.protocol[4] === 's' ? 443 : 80
        }
        let url = 'static/vnc.html?'
        url += 'autoconnect=1&'
        url += `host=${hostname}&port=${port}&`
        url += `path=${websockifyPath}&title=novnc2&`
        url += 'logging=warn&'
        url += `resize=${this.resizeMode}&`
        const storedPassword = this.getStoredVncPassword()
        if (storedPassword) {
          url += `password=${encodeURIComponent(storedPassword)}&`
        }
        url += `cb=${Date.now()}`
        this.$refs.vncFrame.setAttribute('src', url)
      }
    },
    getStoredVncPassword: function () {
      try {
        const urlPassword = new window.URLSearchParams(window.location.search).get('token')
        if (urlPassword) {
          return urlPassword
        }
        const iframeUrl = new window.URL('static/vnc.html', window.location.href)
        const storageKey = `novnc:password:${iframeUrl.origin}${iframeUrl.pathname}`
        return window.sessionStorage.getItem(storageKey) || ''
      } catch (error) {
        return ''
      }
    },
    translate: function (key, fallback) {
      return typeof this.$t === 'function' ? this.$t(key) : fallback
    },
    onMessage: function (message) {
      try {
        let data = JSON.parse(message.data)
        if (data.from === 'novnc') {
          if (data.state) {
            this.vncState = data.state
          }
          if (data.type === 'resizeMode' && data.mode) {
            this.resizeMode = data.mode
          }
          if (data.state === 'connected') {
            this.applyResizeMode()
          }
        }
      } catch (exc) {
      }
    }
  },
  watch: {
  }
}
</script>

<style scoped>
.container {
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    background-color: #000;
    overflow: hidden;
}

iframe {
    border-width: 0px;
    width: 100%;
    height: 100%;
    position: absolute;
    left: 0px;
    top: 0px;
}
</style>
