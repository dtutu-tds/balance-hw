#!/bin/bash
"""
Скрипт настройки окружения для HAProxy Load Balancing Demo
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

# Функция для проверки команды
check_command() {
    if command -v $1 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $1 установлен"
        return 0
    else
        echo -e "${RED}✗${NC} $1 не найден"
        return 1
    fi
}

# Функция для проверки порта
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} Порт $port занят"
        return 1
    else
        echo -e "${GREEN}✓${NC} Порт $port свободен"
        return 0
    fi
}

print_header "HAProxy Load Balancing Demo - Настройка окружения"

echo "Этот скрипт поможет настроить окружение для демонстрации балансировки нагрузки HAProxy"
echo ""

# Проверка системных требований
print_header "Проверка системных требований"

missing_deps=0

# Проверяем основные команды
if ! check_command "python3"; then
    echo "  Установите Python 3: sudo apt-get install python3"
    ((missing_deps++))
fi

if ! check_command "curl"; then
    echo "  Установите curl: sudo apt-get install curl"
    ((missing_deps++))
fi

if ! check_command "haproxy"; then
    echo "  Установите HAProxy: sudo apt-get install haproxy"
    ((missing_deps++))
else
    haproxy_version=$(haproxy -v | head -1)
    echo "  Версия: $haproxy_version"
fi

# Дополнительные инструменты
if ! check_command "ab"; then
    echo -e "${YELLOW}⚠${NC} Apache Bench не найден (опционально для нагрузочного тестирования)"
    echo "  Установите: sudo apt-get install apache2-utils"
fi

if ! check_command "bc"; then
    echo -e "${YELLOW}⚠${NC} bc не найден (требуется для тестовых скриптов)"
    echo "  Установите: sudo apt-get install bc"
    ((missing_deps++))
fi

if ! check_command "lsof"; then
    echo -e "${YELLOW}⚠${NC} lsof не найден (требуется для проверки портов)"
    echo "  Установите: sudo apt-get install lsof"
    ((missing_deps++))
fi

if [[ $missing_deps -gt 0 ]]; then
    echo ""
    echo -e "${RED}Обнаружены отсутствующие зависимости: $missing_deps${NC}"
    echo "Установите их перед продолжением."
    exit 1
fi

echo -e "\n${GREEN}✓ Все системные требования выполнены${NC}"

# Проверка портов
print_header "Проверка доступности портов"

ports_ok=0
required_ports=(8090 8001 8002 8003 8404)

for port in "${required_ports[@]}"; do
    if check_port $port; then
        ((ports_ok++))
    fi
done

if [[ $ports_ok -ne ${#required_ports[@]} ]]; then
    echo ""
    echo -e "${YELLOW}Некоторые порты заняты. Остановите процессы или измените конфигурацию.${NC}"
    echo "Для освобождения портов используйте:"
    echo "  lsof -ti:ПОРТ | xargs kill -9"
fi

# Проверка структуры проекта
print_header "Проверка структуры проекта"

required_dirs=("configs" "servers" "tests" "docs" "scripts")
required_files=(
    "configs/task1-roundrobin.cfg"
    "configs/task2-weighted.cfg"
    "servers/server.py"
    "servers/start_servers.sh"
)

structure_ok=true

for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✓${NC} Директория $dir существует"
    else
        echo -e "${RED}✗${NC} Директория $dir отсутствует"
        structure_ok=false
    fi
done

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} Файл $file существует"
    else
        echo -e "${RED}✗${NC} Файл $file отсутствует"
        structure_ok=false
    fi
done

if [[ "$structure_ok" != true ]]; then
    echo -e "\n${RED}Структура проекта неполная${NC}"
    exit 1
fi

# Проверка прав доступа
print_header "Проверка прав доступа"

# Делаем скрипты исполняемыми
chmod +x servers/start_servers.sh
chmod +x tests/*.sh
chmod +x scripts/*.sh

echo -e "${GREEN}✓${NC} Права доступа настроены"

# Проверка конфигураций HAProxy
print_header "Проверка конфигураций HAProxy"

configs_ok=true

for config in configs/*.cfg; do
    if [[ -f "$config" ]]; then
        echo -n "Проверка $config... "
        if haproxy -c -f "$config" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            echo "Ошибка в конфигурации $config:"
            haproxy -c -f "$config"
            configs_ok=false
        fi
    fi
done

if [[ "$configs_ok" != true ]]; then
    echo -e "\n${RED}Обнаружены ошибки в конфигурациях HAProxy${NC}"
    exit 1
fi

# Создание директории для логов
print_header "Настройка логирования"

if [[ ! -d "logs" ]]; then
    mkdir logs
    echo -e "${GREEN}✓${NC} Создана директория logs"
else
    echo -e "${GREEN}✓${NC} Директория logs уже существует"
fi

# Тестовый запуск Python сервера
print_header "Тестирование Python сервера"

echo "Запуск тестового сервера на порту 9999..."
python3 servers/server.py --port 9999 &
test_server_pid=$!

sleep 2

if kill -0 $test_server_pid 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Python сервер запускается корректно"
    
    # Тестируем HTTP запрос
    if curl -s http://localhost:9999 >/dev/null; then
        echo -e "${GREEN}✓${NC} HTTP запросы обрабатываются"
    else
        echo -e "${YELLOW}⚠${NC} Проблемы с обработкой HTTP запросов"
    fi
    
    # Останавливаем тестовый сервер
    kill $test_server_pid
    wait $test_server_pid 2>/dev/null
    echo -e "${GREEN}✓${NC} Тестовый сервер остановлен"
else
    echo -e "${RED}✗${NC} Не удалось запустить Python сервер"
    exit 1
fi

# Создание файла с переменными окружения
print_header "Создание файла окружения"

cat > .env << EOF
# HAProxy Load Balancing Demo Environment
# Автоматически сгенерировано $(date)

# Порты
HAPROXY_PORT=8090
STATS_PORT=8404
BACKEND_PORTS="8001 8002 8003"

# URLs
HAPROXY_URL="http://localhost:8090"
STATS_URL="http://localhost:8404/stats"

# Аутентификация статистики
STATS_USER="admin"
STATS_PASS="password"

# Тестирование
TEST_DOMAIN="example.local"
TEST_REQUESTS=10
EOF

echo -e "${GREEN}✓${NC} Создан файл .env с переменными окружения"

# Итоговая информация
print_header "Настройка завершена"

echo -e "${GREEN}✓ Окружение настроено успешно!${NC}"
echo ""
echo "Следующие шаги:"
echo ""
echo "1. Запуск backend серверов:"
echo "   cd servers && ./start_servers.sh start"
echo ""
echo "2. Запуск HAProxy для задания 1 (TCP Round-Robin):"
echo "   sudo haproxy -f configs/task1-roundrobin.cfg"
echo ""
echo "3. Запуск HAProxy для задания 2 (HTTP Weighted):"
echo "   sudo haproxy -f configs/task2-weighted.cfg"
echo ""
echo "4. Тестирование:"
echo "   ./tests/test_roundrobin.sh"
echo "   ./tests/test_weighted.sh"
echo "   ./tests/test_domain_routing.sh"
echo ""
echo "5. Мониторинг:"
echo "   Статистика HAProxy: http://localhost:8404/stats"
echo "   Логин: admin, Пароль: password"
echo ""
echo -e "${BLUE}Документация:${NC}"
echo "   README.md - Основная документация"
echo "   docs/README.md - Техническая документация"
echo ""
echo -e "${GREEN}Удачного изучения балансировки нагрузки!${NC}"h
"""
Скрипт настройки окружения для проекта HAProxy балансировки нагрузки
"""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Настройка окружения HAProxy Load Balancing Project ===${NC}"
echo ""

# Проверяем права суперпользователя для установки пакетов
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Внимание: Скрипт запущен от имени root${NC}"
    SUDO=""
else
    SUDO="sudo"
fi

# Функция для проверки успешности команды
check_command() {
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

# 1. Обновление списка пакетов
echo -e "${YELLOW}1. Обновление списка пакетов...${NC}"
$SUDO apt update >/dev/null 2>&1
check_command "Список пакетов обновлен"

# 2. Установка HAProxy
echo -e "${YELLOW}2. Проверка и установка HAProxy...${NC}"
if command -v haproxy >/dev/null 2>&1; then
    haproxy_version=$(haproxy -v | head -1)
    echo -e "${GREEN}✓ HAProxy уже установлен: $haproxy_version${NC}"
else
    echo -e "Установка HAProxy..."
    $SUDO apt install -y haproxy >/dev/null 2>&1
    check_command "HAProxy установлен" || exit 1
fi

# 3. Проверка Python 3
echo -e "${YELLOW}3. Проверка Python 3...${NC}"
if command -v python3 >/dev/null 2>&1; then
    python_version=$(python3 --version)
    echo -e "${GREEN}✓ $python_version доступен${NC}"
else
    echo -e "${RED}✗ Python 3 не найден${NC}"
    echo -e "Установка Python 3..."
    $SUDO apt install -y python3 >/dev/null 2>&1
    check_command "Python 3 установлен" || exit 1
fi

# 4. 