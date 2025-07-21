#!/bin/bash
# Скрипт для тестирования Round-Robin балансировки нагрузки (Задание 1)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
HAPROXY_URL="http://localhost:8090"
NUM_REQUESTS=10
DELAY_BETWEEN_REQUESTS=1

echo -e "${BLUE}=== Тестирование Round-Robin балансировки нагрузки ===${NC}"
echo -e "URL: ${HAPROXY_URL}"
echo -e "Количество запросов: ${NUM_REQUESTS}"
echo -e "Задержка между запросами: ${DELAY_BETWEEN_REQUESTS}с"
echo ""

# Проверяем доступность HAProxy
echo -e "${YELLOW}Проверка доступности HAProxy...${NC}"
if ! curl -s --connect-timeout 5 $HAPROXY_URL >/dev/null; then
    echo -e "${RED}Ошибка: HAProxy недоступен на $HAPROXY_URL${NC}"
    echo "Убедитесь, что:"
    echo "1. HAProxy запущен с конфигурацией task1-roundrobin.cfg"
    echo "2. Backend серверы запущены на портах 8001 и 8002"
    exit 1
fi

echo -e "${GREEN}HAProxy доступен${NC}"
echo ""

# Массивы для подсчета запросов к каждому серверу
declare -A server_count
server_count[8001]=0
server_count[8002]=0

echo -e "${YELLOW}Выполнение тестовых запросов...${NC}"
echo ""

# Выполняем серию запросов
for i in $(seq 1 $NUM_REQUESTS); do
    echo -e "${BLUE}Запрос $i:${NC}"
    
    # Выполняем запрос и извлекаем информацию о сервере
    response=$(curl -s $HAPROXY_URL)
    
    if [[ $? -eq 0 ]]; then
        # Извлекаем порт сервера из ответа
        server_port=$(echo "$response" | grep -o "Порт [0-9]*" | grep -o "[0-9]*")
        
        if [[ -n $server_port ]]; then
            echo -e "  └─ ${GREEN}Ответ от сервера на порту $server_port${NC}"
            ((server_count[$server_port]++))
        else
            echo -e "  └─ ${YELLOW}Не удалось определить порт сервера${NC}"
        fi
    else
        echo -e "  └─ ${RED}Ошибка запроса${NC}"
    fi
    
    # Задержка между запросами
    if [[ $i -lt $NUM_REQUESTS ]]; then
        sleep $DELAY_BETWEEN_REQUESTS
    fi
done

echo ""
echo -e "${BLUE}=== Результаты тестирования ===${NC}"
echo ""

# Выводим статистику
total_requests=0
for port in "${!server_count[@]}"; do
    count=${server_count[$port]}
    percentage=$(( count * 100 / NUM_REQUESTS ))
    echo -e "Сервер на порту $port: ${GREEN}$count запросов${NC} (${percentage}%)"
    ((total_requests += count))
done

echo ""
echo -e "Всего обработано запросов: $total_requests из $NUM_REQUESTS"

# Анализ результатов
echo ""
echo -e "${BLUE}=== Анализ балансировки ===${NC}"

if [[ $total_requests -eq $NUM_REQUESTS ]]; then
    # Проверяем равномерность распределения
    server1_count=${server_count[8001]}
    server2_count=${server_count[8002]}
    
    difference=$((server1_count - server2_count))
    if [[ $difference -lt 0 ]]; then
        difference=$((-difference))
    fi
    
    if [[ $difference -le 1 ]]; then
        echo -e "${GREEN}✓ Балансировка работает корректно${NC}"
        echo -e "  Запросы распределены равномерно между серверами"
    else
        echo -e "${YELLOW}⚠ Балансировка работает, но распределение неравномерное${NC}"
        echo -e "  Разница в количестве запросов: $difference"
        echo -e "  Это может быть нормально для небольшого количества запросов"
    fi
else
    echo -e "${RED}✗ Обнаружены проблемы с балансировкой${NC}"
    echo -e "  Не все запросы были обработаны успешно"
fi

echo ""
echo -e "${BLUE}=== Рекомендации ===${NC}"
echo "1. Для более точного тестирования увеличьте количество запросов"
echo "2. Проверьте логи HAProxy для детальной информации"
echo "3. Убедитесь, что оба backend-сервера работают стабильно"

# Проверяем статистику HAProxy
echo ""
echo -e "${YELLOW}Статистика HAProxy доступна по адресу: http://localhost:8404/stats${NC}"
echo -e "Логин: admin, Пароль: password"