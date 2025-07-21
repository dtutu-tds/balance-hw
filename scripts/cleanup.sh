#!/bin/bash
"""
Скрипт очистки окружения HAProxy Load Balancing Demo
"""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода заголовков
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_header "HAProxy Load Balancing Demo - Очистка окружения"

echo "Этот скрипт остановит все процессы и очистит временные файлы"
echo ""

# Проверяем, нужно ли подтверждение
if [[ "$1" != "--force" ]]; then
    echo -e "${YELLOW}Вы уверены, что хотите очистить окружение? [y/N]${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Отменено пользователем"
        exit 0
    fi
fi

# Остановка HAProxy процессов
print_header "Остановка HAProxy процессов"

haproxy_pids=$(pgrep -f "haproxy.*\.cfg")
if [[ -n "$haproxy_pids" ]]; then
    echo "Найдены HAProxy процессы: $haproxy_pids"
    for pid in $haproxy_pids; do
        echo "Остановка HAProxy процесса $pid..."
        if kill $pid 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Процесс $pid остановлен"
        else
            echo -e "${YELLOW}⚠${NC} Не удалось остановить процесс $pid (возможно, требуются права sudo)"
            sudo kill $pid 2>/dev/null && echo -e "${GREEN}✓${NC} Процесс $pid остановлен с sudo"
        fi
    done
else
    echo -e "${GREEN}✓${NC} HAProxy процессы не найдены"
fi

# Остановка Python серверов
print_header "Остановка Python серверов"

# Используем скрипт управления серверами если он доступен
if [[ -f "servers/start_servers.sh" ]]; then
    echo "Использование скрипта управления серверами..."
    cd servers && ./start_servers.sh stop
    cd ..
else
    # Ручная остановка Python серверов
    python_pids=$(pgrep -f "python.*server\.py")
    if [[ -n "$python_pids" ]]; then
        echo "Найдены Python серверы: $python_pids"
        for pid in $python_pids; do
            echo "Остановка Python сервера $pid..."
            kill $pid 2>/dev/null && echo -e "${GREEN}✓${NC} Процесс $pid остановлен"
        done
    else
        echo -e "${GREEN}✓${NC} Python серверы не найдены"
    fi
fi

# Очистка файлов PID
print_header "Очистка файлов PID"

pid_files=("servers/server_pids.txt")
for pidfile in "${pid_files[@]}"; do
    if [[ -f "$pidfile" ]]; then
        rm -f "$pidfile"
        echo -e "${GREEN}✓${NC} Удален $pidfile"
    fi
done

# Очистка логов
print_header "Очистка файлов логов"

log_patterns=(
    "servers/server_*.log"
    "logs/*.log"
    "*.log"
)

for pattern in "${log_patterns[@]}"; do
    files=$(ls $pattern 2>/dev/null)
    if [[ -n "$files" ]]; then
        for file in $files; do
            rm -f "$file"
            echo -e "${GREEN}✓${NC} Удален $file"
        done
    fi
done

# Очистка временных файлов
print_header "Очистка временных файлов"

temp_patterns=(
    "*.tmp"
    "*.pid"
    ".env.backup"
    "nohup.out"
)

for pattern in "${temp_patterns[@]}"; do
    files=$(ls $pattern 2>/dev/null)
    if [[ -n "$files" ]]; then
        for file in $files; do
            rm -f "$file"
            echo -e "${GREEN}✓${NC} Удален $file"
        done
    fi
done

# Проверка занятых портов
print_header "Проверка портов"

ports=(8090 8001 8002 8003 8404)
occupied_ports=()

for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        occupied_ports+=($port)
        echo -e "${YELLOW}⚠${NC} Порт $port все еще занят"
        
        # Показываем, какой процесс занимает порт
        process_info=$(lsof -Pi :$port -sTCP:LISTEN | tail -n +2)
        echo "  $process_info"
    else
        echo -e "${GREEN}✓${NC} Порт $port свободен"
    fi
done

# Предложение принудительной очистки портов
if [[ ${#occupied_ports[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Обнаружены занятые порты: ${occupied_ports[*]}${NC}"
    echo "Хотите принудительно освободить их? [y/N]"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        for port in "${occupied_ports[@]}"; do
            echo "Принудительное освобождение порта $port..."
            pids=$(lsof -ti:$port)
            for pid in $pids; do
                kill -9 $pid 2>/dev/null && echo -e "${GREEN}✓${NC} Процесс $pid завершен"
            done
        done
    fi
fi

# Очистка системных ресурсов
print_header "Очистка системных ресурсов"

# Очистка shared memory segments (если используются)
ipcs -m | grep $(whoami) | awk '{print $2}' | xargs -r ipcrm -m 2>/dev/null
echo -e "${GREEN}✓${NC} Очищены shared memory segments"

# Очистка временных сокетов
find /tmp -name "*haproxy*" -user $(whoami) -delete 2>/dev/null
find /tmp -name "*server*" -user $(whoami) -delete 2>/dev/null
echo -e "${GREEN}✓${NC} Очищены временные сокеты"

# Создание отчета об очистке
print_header "Создание отчета"

report_file="cleanup_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$report_file" << EOF
HAProxy Load Balancing Demo - Отчет об очистке
Дата: $(date)
Пользователь: $(whoami)
Хост: $(hostname)

Остановленные процессы:
$(ps aux | grep -E "(haproxy|server\.py)" | grep -v grep || echo "Нет активных процессов")

Освобожденные порты:
$(for port in "${ports[@]}"; do
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ✓ Порт $port свободен"
    else
        echo "  ⚠ Порт $port занят"
    fi
done)

Удаленные файлы:
$(find . -name "*.log" -o -name "*.pid" -o -name "*.tmp" 2>/dev/null || echo "Нет файлов для удаления")

Статус очистки: ЗАВЕРШЕНА
EOF

echo -e "${GREEN}✓${NC} Создан отчет: $report_file"

# Проверка состояния после очистки
print_header "Проверка состояния после очистки"

echo "Активные процессы HAProxy/Python:"
active_processes=$(ps aux | grep -E "(haproxy|server\.py)" | grep -v grep)
if [[ -n "$active_processes" ]]; then
    echo -e "${YELLOW}⚠${NC} Найдены активные процессы:"
    echo "$active_processes"
else
    echo -e "${GREEN}✓${NC} Активные процессы не найдены"
fi

echo ""
echo "Занятые порты из списка проекта:"
any_occupied=false
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} Порт $port занят"
        any_occupied=true
    fi
done

if [[ "$any_occupied" == false ]]; then
    echo -e "${GREEN}✓${NC} Все порты проекта свободны"
fi

# Итоговое сообщение
print_header "Очистка завершена"

echo -e "${GREEN}✓ Окружение очищено успешно!${NC}"
echo ""
echo "Что было сделано:"
echo "• Остановлены все HAProxy процессы"
echo "• Остановлены все Python серверы"
echo "• Удалены файлы логов и PID"
echo "• Очищены временные файлы"
echo "• Освобождены системные ресурсы"
echo ""
echo "Для повторного запуска проекта используйте:"
echo "  ./scripts/setup.sh"
echo ""
echo -e "${BLUE}Отчет сохранен в: $report_file${NC}""
Скрипт очистки окружения проекта HAProxy балансировки нагрузки
"""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Очистка окружения HAProxy Load Balancing Project ===${NC}"
echo ""

# 1. Остановка Python серверов
echo -e "${YELLOW}1. Остановка Python серверов...${NC}"
cd servers 2>/dev/null
if [[ -f start_servers.sh ]]; then
    ./start_servers.sh stop
else
    echo -e "${YELLOW}Скрипт управления серверами не найден${NC}"
fi
cd - >/dev/null

# 2. Остановка HAProxy процессов
echo -e "${YELLOW}2. Остановка HAProxy процессов...${NC}"
haproxy_pids=$(pgrep -f "haproxy.*task[12]")
if [[ -n $haproxy_pids ]]; then
    echo -e "Найдены процессы HAProxy: $haproxy_pids"
    for pid in $haproxy_pids; do
        if kill $pid 2>/dev/null; then
            echo -e "${GREEN}✓ Процесс HAProxy $pid остановлен${NC}"
        else
            echo -e "${YELLOW}⚠ Не удалось остановить процесс $pid${NC}"
        fi
    done
    
    # Ждем завершения процессов
    sleep 2
    
    # Принудительное завершение если необходимо
    remaining_pids=$(pgrep -f "haproxy.*task[12]")
    if [[ -n $remaining_pids ]]; then
        echo -e "${YELLOW}Принудительное завершение оставшихся процессов...${NC}"
        for pid in $remaining_pids; do
            kill -9 $pid 2>/dev/null
            echo -e "${GREEN}✓ Процесс $pid принудительно завершен${NC}"
        done
    fi
else
    echo -e "${GREEN}✓ Процессы HAProxy не найдены${NC}"
fi

# 3. Очистка файлов логов
echo -e "${YELLOW}3. Очистка файлов логов...${NC}"
log_files_found=0

# Логи серверов
if ls servers/server_*.log >/dev/null 2>&1; then
    rm -f servers/server_*.log
    echo -e "${GREEN}✓ Логи серверов удалены${NC}"
    ((log_files_found++))
fi

# PID файлы серверов
if [[ -f servers/server_pids.txt ]]; then
    rm -f servers/server_pids.txt
    echo -e "${GREEN}✓ PID файл серверов удален${NC}"
    ((log_files_found++))
fi

# Общие логи
if ls logs/*.log >/dev/null 2>&1; then
    rm -f logs/*.log
    echo -e "${GREEN}✓ Общие логи удалены${NC}"
    ((log_files_found++))
fi

if [[ $log_files_found -eq 0 ]]; then
    echo -e "${GREEN}✓ Файлы логов не найдены${NC}"
fi

# 4. Проверка освобождения портов
echo -e "${YELLOW}4. Проверка освобождения портов...${NC}"
ports_to_check=(8001 8002 8003 8090 8404)
occupied_ports=()

for port in "${ports_to_check[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        occupied_ports+=($port)
    fi
done

if [[ ${#occupied_ports[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ Все порты освобождены${NC}"
else
    echo -e "${YELLOW}⚠ Следующие порты все еще заняты: ${occupied_ports[*]}${NC}"
    echo -e "Возможно потребуется ручная остановка процессов"
    
    for port in "${occupied_ports[@]}"; do
        pid=$(lsof -Pi :$port -sTCP:LISTEN -t)
        if [[ -n $pid ]]; then
            process_info=$(ps -p $pid -o comm= 2>/dev/null)
            echo -e "  Порт $port: PID $pid ($process_info)"
        fi
    done
fi

# 5. Очистка временных файлов
echo -e "${YELLOW}5. Очистка временных файлов...${NC}"
temp_files_found=0

# Временные файлы curl
if ls /tmp/curl_* >/dev/null 2>&1; then
    rm -f /tmp/curl_*
    echo -e "${GREEN}✓ Временные файлы curl удалены${NC}"
    ((temp_files_found++))
fi

# Файлы блокировки
if ls *.lock >/dev/null 2>&1; then
    rm -f *.lock
    echo -e "${GREEN}✓ Файлы блокировки удалены${NC}"
    ((temp_files_found++))
fi

if [[ $temp_files_found -eq 0 ]]; then
    echo -e "${GREEN}✓ Временные файлы не найдены${NC}"
fi

# 6. Проверка системных ресурсов
echo -e "${YELLOW}6. Проверка системных ресурсов...${NC}"

# Проверяем использование памяти процессами проекта
project_processes=$(pgrep -f "(python3.*server\.py|haproxy.*task)")
if [[ -n $project_processes ]]; then
    echo -e "${YELLOW}⚠ Найдены активные процессы проекта:${NC}"
    ps -p $project_processes -o pid,ppid,cmd
else
    echo -e "${GREEN}✓ Активные процессы проекта не найдены${NC}"
fi

# 7. Опциональная очистка установленных пакетов
echo ""
echo -e "${BLUE}=== Дополнительные опции очистки