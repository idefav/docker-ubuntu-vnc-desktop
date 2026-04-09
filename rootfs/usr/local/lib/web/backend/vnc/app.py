from __future__ import (
    absolute_import, division, print_function, with_statement
)
import os
from flask import (
    Flask,
    request,
    jsonify,
)
from gevent import sleep
from .response import httperror
from .state import state
from .log import log


# Flask app
app = Flask('novnc2')
app.config.from_object('config.Default')
app.config.from_object(os.environ.get('CONFIG') or 'config.Development')


@app.route('/api/state')
@httperror
def apistate():
    state.wait(int(request.args.get('id', -1)), 30)
    mystate = state.to_dict()
    return jsonify({
        'code': 200,
        'data': mystate,
    })


@app.route('/api/health')
def apihealth():
    if state.health:
        return 'success'
    abort(503, 'unhealthy')


@app.route('/api/reset')
@httperror
def reset():
    if 'w' in request.args and 'h' in request.args:
        args = {
            'w': int(request.args.get('w')),
            'h': int(request.args.get('h')),
        }
        state.set_size(args['w'], args['h'])

    state.apply_and_restart()

    # check all running
    for i in range(40):
        if state.health:
            break
        sleep(1)
        log.info('wait services is ready...')
    else:
        raise RuntimeError('service is not ready, please restart container')
    return jsonify({'code': 200})


@app.route('/resize')
@httperror
def apiresize():
    state.reset_size()
    return '<html><head><script type = "text/javascript">var h=window.location.href;window.location.href=h.substring(0,h.length-6);</script></head></html>'


if __name__ == '__main__':
    app.run(host=app.config['ADDRESS'], port=app.config['PORT'])
