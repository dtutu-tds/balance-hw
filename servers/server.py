#!/usr/bin/env python3
"""
Простой HTTP-сервер с логированием для демонстрации балансировки нагрузки HAProxy
"""

import http.server
import socketserver
import argparse
import datetime
import sys
import signal
import threading

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Получаем информацию о запросе
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        client_ip = self.client_address[0]
        server_port = self.server.server_address[1]
        
        # Логируем запрос в файл (без вывода в терминал)
        log_message = f"[{timestamp}] Запрос от {client_ip} обработан сервером на порту {server_port}\n"
        
        # Записываем в лог-файл
        try:
            with open(f"logs/server_{server_port}.log", "a") as log_file:
                log_file.write(log_message)
        except:
            pass  # Игнорируем ошибки записи в лог
        
        # Создаем HTML-ответ с информацией о сервере
        response_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Backend Server {server_port}</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Backend Server - Порт {server_port}</h1>
    <p><strong>Время запроса:</strong> {timestamp}</p>
    <p><strong>IP клиента:</strong> {client_ip}</p>
    <p><strong>Порт сервера:</strong> {server_port}</p>
    <p><strong>Путь запроса:</strong> {self.path}</p>
    <hr>
    <p>Этот ответ сгенерирован Python HTTP-сервером для демонстрации балансировки нагрузки HAProxy</p>
</body>
</html>
        """.strip()
        
        # Отправляем ответ
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.send_header('Content-length', str(len(response_content.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(response_content.encode('utf-8'))

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """HTTP-сервер с поддержкой многопоточности"""
    daemon_threads = True

def signal_handler(signum, frame):
    """Обработчик сигналов для корректного завершения"""
    print(f"\nПолучен сигнал {signum}. Завершение работы сервера...")
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description='Простой HTTP-сервер для демонстрации балансировки нагрузки')
    parser.add_argument('--port', type=int, default=8001, help='Порт для прослушивания (по умолчанию: 8001)')
    parser.add_argument('--host', default='127.0.0.1', help='Хост для прослушивания (по умолчанию: 127.0.0.1)')
    
    args = parser.parse_args()
    
    # Настраиваем обработчики сигналов
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Создаем и запускаем сервер
        with ThreadedHTTPServer((args.host, args.port), CustomHTTPRequestHandler) as httpd:
            print(f"Сервер запущен на {args.host}:{args.port}")
            print(f"Время запуска: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print("Нажмите Ctrl+C для остановки сервера")
            httpd.serve_forever()
    except OSError as e:
        print(f"Ошибка запуска сервера: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nСервер остановлен пользователем")
        sys.exit(0)

if __name__ == '__main__':
    main()