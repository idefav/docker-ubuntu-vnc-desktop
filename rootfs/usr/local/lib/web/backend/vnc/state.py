from __future__ import (
    absolute_import, division, print_function, with_statement
)
from os import environ
from pathlib import Path
from gevent.event import Event
from gevent import subprocess as gsp
from re import search as research
from .response import BadRequest
from .log import log


RESOLUTION_FILE = Path(environ.get('RESOLUTION_FILE', '/run/desktop-resolution'))


class State(object):
    def __init__(self):
        self._eid = 0
        self._event = Event()
        self._w = self._h = self._health = None
        self.size_changed_count = 0

    def wait(self, eid, timeout=5):
        if eid < self._eid:
            return
        self._event.clear()
        self._event.wait(timeout)
        return self._eid

    def notify(self):
        self._eid += 1
        self._event.set()

    def _update_health(self):
        health = True
        proc = gsp.run([
            'supervisorctl', '-c', '/etc/supervisor/supervisord.conf',
            'status'
        ], encoding='UTF-8', stdout=gsp.PIPE, stderr=gsp.STDOUT, check=False)
        if proc.returncode not in (0, 3):
            raise gsp.CalledProcessError(proc.returncode, proc.args, output=proc.stdout)
        output = proc.stdout or ''
        for line in output.strip().split('\n'):
            if not line.startswith('web') and line.find('RUNNING') < 0:
                health = False
                break
        if self._health != health:
            self._health = health
            self.notify()
        return self._health

    def to_dict(self):
        self._update_health()

        state = {
            'id': self._eid,
            'config': {
                'fixedResolution': 'RESOLUTION' in environ,
                'sizeChangedCount': self.size_changed_count
            }
        }

        self._update_size()
        state.update({
            'width': self.w,
            'height': self.h,
        })

        return state

    def set_size(self, w, h):
        if w <= 0 or h <= 0:
            raise BadRequest('invalid resolution')
        RESOLUTION_FILE.parent.mkdir(parents=True, exist_ok=True)
        RESOLUTION_FILE.write_text('{}x{}'.format(w, h))
        self.size_changed_count += 1

    def apply_and_restart(self):
        gsp.check_call([
            'supervisorctl', '-c', '/etc/supervisor/supervisord.conf',
            'restart', 'x:'
        ])
        self._w = self._h = self._health = None
        self.notify()

    def switch_video(self, onoff):
        return

    def _update_size(self):
        if self._w is not None and self._h is not None:
            return
        xenvs = {
            'DISPLAY': ':1',
        }
        try:
            output = gsp.check_output([
                'xdpyinfo'
            ], env=xenvs).decode('utf-8')
            mobj = research(r'dimensions:\s+(\d+)x(\d+)\s+pixels', output)
            if mobj is not None:
                w, h = int(mobj.group(1)), int(mobj.group(2))
                changed = False
                if self._w != w:
                    changed = True
                    self._w = w
                if self._h != h:
                    changed = True
                    self._h = h
                if changed:
                    self.notify()
        except gsp.CalledProcessError as e:
            log.warn('failed to get display size: ' + str(e))

    def reset_size(self):
        self.size_changed_count = 0

    @property
    def w(self):
        return self._w

    @property
    def h(self):
        return self._h

    @property
    def health(self):
        self._update_health()
        return self._health


state = State()
