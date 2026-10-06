#!/bin/sh
# Opens the driver's shift diary in the browser. macOS and Linux; on Windows
# use start.bat. Double-click the file, or run `sh demo/start.command`.
#
# Nothing is installed or built: the script serves the ready-made web client
# from demo/web/ on this computer only, and the client talks to the API that
# is deployed on Railway. Close the window (or press Ctrl+C) to stop.

cd "$(dirname "$0")/web" || {
  echo "Не найдена папка demo/web рядом со скриптом."
  exit 1
}

# macOS ships /usr/bin/python3 as a stub that offers to install the developer
# tools when they are missing; its built-in Ruby works out of the box.
python_ok() {
  command -v python3 >/dev/null 2>&1 || return 1
  [ "$(uname)" != Darwin ] && return 0
  [ "$(command -v python3)" != /usr/bin/python3 ] && return 0
  xcode-select -p >/dev/null 2>&1
}

# The system Ruby of macOS comes first: newer Rubies no longer bundle the
# web server (webrick), so one installed by the user may not have it.
ruby_ok() {
  for RUBY in /usr/bin/ruby ruby; do
    command -v "$RUBY" >/dev/null 2>&1 &&
      "$RUBY" -e 'require "webrick"' >/dev/null 2>&1 && return 0
  done
  return 1
}

serve() { # serve <port>
  case "$SERVER" in
    python) exec python3 -m http.server "$1" --bind 127.0.0.1 ;;
    ruby) exec "$RUBY" -run -e httpd . --port="$1" --bind-address=127.0.0.1 ;;
  esac
}

# DEMO_SERVER=python|ruby forces one of them (for testing the script itself).
if [ "${DEMO_SERVER:-}" = ruby ] && ruby_ok; then
  SERVER=ruby
elif [ "${DEMO_SERVER:-}" != ruby ] && python_ok; then
  SERVER=python
elif ruby_ok; then
  SERVER=ruby
else
  echo "Нужен Python 3 или Ruby, чтобы раздать страницу. Установите Python: https://www.python.org/downloads/"
  exit 1
fi

responds() { # responds <port>
  if command -v curl >/dev/null 2>&1; then
    curl -fs -o /dev/null "http://127.0.0.1:$1/index.html"
  else
    sleep 2
  fi
}

PID=
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null' EXIT INT TERM

# The first free port out of a few: another copy may already be running.
for PORT in 8765 8766 8767 8768 8769; do
  (serve "$PORT") >/dev/null 2>&1 &
  PID=$!
  tries=0
  while kill -0 "$PID" 2>/dev/null && [ "$tries" -lt 25 ]; do
    # Still alive a moment later: a server that lost the race for the port
    # exits, and the answer came from whoever holds it.
    if responds "$PORT" && sleep 0.5 && kill -0 "$PID" 2>/dev/null; then
      URL="http://localhost:$PORT/"
      echo "Дневник смен открыт по адресу $URL"
      echo "Чтобы остановить, закройте это окно или нажмите Ctrl+C."
      if [ -n "${DEMO_NO_BROWSER:-}" ]; then
        :
      elif [ "$(uname)" = Darwin ]; then
        open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL"
      elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$URL" >/dev/null 2>&1
      else
        echo "Откройте этот адрес в браузере."
      fi
      wait "$PID"
      exit 0
    fi
    tries=$((tries + 1))
    sleep 0.2
  done
  kill "$PID" 2>/dev/null
  PID=
done

echo "Не удалось запустить локальный сервер: порты 8765–8769 заняты."
exit 1
