<template>
  <div ref="container" style="width: 100%; height: 100%; background-color: #000;">
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
      // stopped -> connected -> disconnected
      vncState: 'stopped',
      config: {
        mode: 'vnc'
      },
      stateID: -1,
      // retry
      errorMessage: '',
      // vnc canvas size
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
      const frame = this.$refs.vncFrame
      return {
        w: Math.max(Math.round(frame.clientWidth), 0),
        h: Math.max(Math.round(frame.clientHeight), 0)
      }
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
        this.setResizeMode('scale')
      }, 250)
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
        const response = await this.$http.get('api/state', {params: params})
        const body = response.data
        if (body.code !== 200) {
          this.stateErrorCount += 1
          if (this.stateErrorCount > 10) {
            this.errorMessage = this.translate('serviceIsUnavailable', 'Service is unavailable')
            throw this.errorMessage
          }
        }

        // long polling
        this.stateID = body.data.id
        this.width = body.data.width || 0
        this.height = body.data.height || 0
        this.fixedResolution = body.data.config.fixedResolution
        this.setResizeMode(this.fixedResolution ? 'scale' : 'remote')

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
      console.log(`connecting...`)
      this.errorMessage = ''
      let websockifyPath = location.pathname.substr(1) + 'websockify'
      if (force || this.vncState === 'stopped') {
        this.vncState = 'connecting'
        let hostname = window.location.hostname
        let port = window.location.port
        if (!port) {
          port = window.location.protocol[4] === 's' ? 443 : 80
        }
        let url = 'static/novnc/vnc.html?'
        url += 'autoconnect=1&'
        url += `host=${hostname}&port=${port}&`
        url += `path=${websockifyPath}&title=novnc2&`
        url += `logging=warn&`
        url += `resize=${this.resizeMode}`
        this.$refs.vncFrame.setAttribute('src', url)
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
            this.setResizeMode(this.resizeMode)
          }
        }
      } catch (exc) {
        // SyntaxError if JSON pasrse error
      }
    }
  },
  computed: {
  },
  watch: {
  }
}
</script>

<style scoped>
body {
    margin: 0px;
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
