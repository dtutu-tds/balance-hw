#!/bin/bash
# Скрипт для запуска и управления Python backend-серверами

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Файл для хранения PID процессов
PIDFILE="server_pids.txt"

# Функция для вывода справки
show_help() {
    echo "Использование: $0 [КОМАНДА] [ОПЦИИ]"
    echo ""
    echo "КОМАНДЫ:"
    echo "  start [ports]    - Запустить серверы на указанных портах (по умолчанию: 8001 8002)"
    echo "  start3           - Запустить 3 сервера на портах 8001, 8002, 8003"
    echo "  stop             - Остановить все запущенные серверы"
    echo "  status           - Показать статус серверов"
    echo "  restart [ports]  - Перезапустить серверы"
    echo "  help             - Показать эту справку"
    echo ""
    echo "ПРИМЕРЫ:"
    echo "  $0 start                    # Запустить серверы на портах 8001 и 8002"
    echo "  $0 start 8001 8002 8003     # Запустить серверы на указанных портах"
    echo "  $0 start3                   # Запустить 3 сервера для задания 2"
    echo "  $0 stop                     # Остановить все серверы"
}

# Функция для запуска сервера
start_server() {
    local port=$1
    
    echo -e "${YELLOW}Запуск сервера на порту ${port}...${NC}"
    
    # Проверяем, не занят ли порт
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}Порт ${port} уже занят!${NC}"
        return 1
    fi
    
    # Запускаем сервер в фоне (логи записываются автоматически в logs/server_${port}.log)
    python3 server.py --port $port >/dev/null 2>&1 &
    local pid=$!
    
    # Сохраняем PID
    echo "${port}:${pid}" >> $PIDFILE
    
    # Проверяем, что сервер запустился
    sleep 1
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}Сервер на порту ${port} запущен (PID: ${pid})${NC}"
        echo -e "Логи: logs/server_${port}.log"
        return 0
    else
        echo -e "${RED}Не удалось запустить сервер на порту ${port}${NC}"
        return 1
    fi
}

# Функция для остановки всех серверов
stop_servers() {
    echo -e "${YELLOW}Остановка серверов...${NC}"
    
    if [[ ! -f $PIDFILE ]]; then
        echo "Файл с PID не найден. Серверы не запущены или уже остановлены."
        return 0
    fi
    
    while IFS=':' read -r port pid; do
        if [[ -n $pid ]] && kill -0 $pid 2>/dev/null; then
            echo -e "Остановка сервера на порту ${port} (PID: ${pid})"
            kill $pid
            # Ждем завершения процесса
            for i in {1..5}; do
                if ! kill -0 $pid 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            # Принудительное завершение если процесс не завершился
            if kill -0 $pid 2>/dev/null; then
                echo -e "${YELLOW}Принудительное завершение процесса ${pid}${NC}"
                kill -9 $pid
            fi
            echo -e "${GREEN}Сервер на порту ${port} остановлен${NC}"
        else
            echo -e "${YELLOW}Процесс ${pid} для порта ${port} не найден${NC}"
        fi
    done < $PIDFILE
    
    # Удаляем файл с PID
    rm -f $PIDFILE
    
    # Очищаем логи (старые файлы в текущей директории, если есть)
    rm -f server_*.log
    
    echo -e "${GREEN}Все серверы остановлены${NC}"
}

# Функция для показа статуса серверов
show_status() {
    echo -e "${YELLOW}Статус серверов:${NC}"
    
    if [[ ! -f $PIDFILE ]]; then
        echo "Серверы не запущены"
        return 0
    fi
    
    while IFS=':' read -r port pid; do
        if [[ -n $pid ]] && kill -0 $pid 2>/dev/null; then
            echo -e "${GREEN}Порт ${port}: ЗАПУЩЕН (PID: ${pid})${NC}"
            # Проверяем доступность порта
            if curl -s http://localhost:$port >/dev/null 2>&1; then
                echo -e "  └─ HTTP-сервер отвечает"
            else
                echo -e "  └─ ${YELLOW}HTTP-сервер не отвечает${NC}"
            fi
        else
            echo -e "${RED}Порт ${port}: ОСТАНОВЛЕН (PID: ${pid} не найден)${NC}"
        fi
    done < $PIDFILE
}

# Основная логика
case "$1" in
    "start")
        # Останавливаем существующие серверы
        if [[ -f $PIDFILE ]]; then
            stop_servers
        fi
        
        # Определяем порты для запуска
        if [[ $# -gt 1 ]]; then
            ports=("${@:2}")
        else
            ports=(8001 8002)
        fi
        
        echo -e "${YELLOW}Запуск серверов на портах: ${ports[*]}${NC}"
        
        for port in "${ports[@]}"; do
            start_server $port
        done
        
        echo ""
        show_status
        ;;
    
    "start3")
        # Останавливаем существующие серверы
        if [[ -f $PIDFILE ]]; then
            stop_servers
        fi
        
        echo -e "${YELLOW}Запуск 3 серверов для задания 2...${NC}"
        
        for port in 8001 8002 8003; do
            start_server $port
        done
        
        echo ""
        show_status
        ;;
    
    "stop")
        stop_servers
        ;;
    
    "status")
        show_status
        ;;
    
    "restart")
        stop_servers
        sleep 2
        
        # Определяем порты для запуска
        if [[ $# -gt 1 ]]; then
            ports=("${@:2}")
        else
            ports=(8001 8002)
        fi
        
        echo -e "${YELLOW}Перезапуск серверов на портах: ${ports[*]}${NC}"
        
        for port in "${ports[@]}"; do
            start_server $port
        done
        
        echo ""
        show_status
        ;;
    
    "help"|"-h"|"--help")
        show_help
        ;;
    
    *)
        echo -e "${RED}Неизвестная команда: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac