#!/bin/bash
"""
Скрипт для тестирования взвешенной балансировки нагрузки (Задание 2)
"""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
HAPROXY_URL="http://localhost:8090"
NUM_REQUESTS=90  # Кратно сумме весов (2+3+4=9)
DELAY_BETWEEN_REQUESTS=0.1

echo -e "${BLUE}=== Тестирование взвешенной балансировки нагрузки ===${NC}"
echo -e "URL: ${HAPROXY_URL}"
echo -e "Host: example.local"
echo -e "Количество запросов: ${NUM_REQUESTS}"
echo -e "Ожидаемые веса: Сервер1=2, Сервер2=3, Сервер3=4"
echo ""

# Проверяем доступность HAProxy
echo -e "${YELLOW}Проверка доступности HAProxy...${NC}"
if ! curl -s --connect-timeout 5 -H "Host: example.local" $HAPROXY_URL >/dev/null; then
    echo -e "${RED}Ошибка: HAProxy недоступен на $HAPROXY_URL${NC}"
    echo "Убедитесь, что:"
    echo "1. HAProxy запущен с конфигурацией task2-weighted.cfg"
    echo "2. Backend серверы запущены на портах 8001, 8002 и 8003"
    exit 1
fi

echo -e "${GREEN}HAProxy доступен${NC}"
echo ""

# Массивы для подсчета запросов к каждому серверу
declare -A server_count
server_count[8001]=0
server_count[8002]=0
server_count[8003]=0

echo -e "${YELLOW}Выполнение тестовых запросов с заголовком Host: example.local...${NC}"
echo ""

# Выполняем серию запросов
for i in $(seq 1 $NUM_REQUESTS); do
    if [[ $((i % 10)) -eq 1 ]]; then
        echo -e "${BLUE}Запросы $i-$((i+9)):${NC}"
    fi
    
    # Выполняем запрос с заголовком Host
    response=$(curl -s -H "Host: example.local" $HAPROXY_URL)
    
    if [[ $? -eq 0 ]]; then
        # Извлекаем порт сервера из ответа
        server_port=$(echo "$response" | grep -o "Порт [0-9]*" | grep -o "[0-9]*")
        
        if [[ -n $server_port ]]; then
            ((server_count[$server_port]++))
            if [[ $((i % 10)) -eq 0 ]]; then
                echo -e "  └─ Последний ответ от сервера на порту $server_port"
            fi
        fi
    fi
    
    # Небольшая задержка между запросами
    sleep $DELAY_BETWEEN_REQUESTS
done

echo ""
echo -e "${BLUE}=== Результаты тестирования ===${NC}"
echo ""

# Выводим статистику
total_requests=0
expected_weights=(2 3 4)
actual_weights=()

echo -e "Распределение запросов:"
for port in 8001 8002 8003; do
    count=${server_count[$port]}
    percentage=$(echo "scale=1; $count * 100 / $NUM_REQUESTS" | bc -l)
    echo -e "Сервер на порту $port: ${GREEN}$count запросов${NC} (${percentage}%)"
    ((total_requests += count))
    
    # Вычисляем фактический вес
    actual_weight=$(echo "scale=2; $count * 9 / $NUM_REQUESTS" | bc -l)
    actual_weights+=($actual_weight)
done

echo ""
echo -e "Всего обработано запросов: $total_requests из $NUM_REQUESTS"

# Анализ весов
echo ""
echo -e "${BLUE}=== Анализ весовой балансировки ===${NC}"
echo ""

echo -e "Сравнение ожидаемых и фактических весов:"
ports=(8001 8002 8003)
for i in {0..2}; do
    port=${ports[$i]}
    expected=${expected_weights[$i]}
    actual=${actual_weights[$i]}
    
    # Вычисляем отклонение
    deviation=$(echo "scale=1; ($actual - $expected) * 100 / $expected" | bc -l)
    
    echo -e "Сервер $port:"
    echo -e "  Ожидаемый вес: $expected"
    echo -e "  Фактический вес: $actual"
    echo -e "  Отклонение: ${deviation}%"
    
    # Проверяем, находится ли отклонение в допустимых пределах (±20%)
    deviation_abs=$(echo $deviation | tr -d '-')
    if (( $(echo "$deviation_abs <= 20" | bc -l) )); then
        echo -e "  ${GREEN}✓ В пределах нормы${NC}"
    else
        echo -e "  ${YELLOW}⚠ Значительное отклонение${NC}"
    fi
    echo ""
done

# Общая оценка
echo -e "${BLUE}=== Общая оценка ===${NC}"

if [[ $total_requests -eq $NUM_REQUESTS ]]; then
    echo -e "${GREEN}✓ Все запросы обработаны успешно${NC}"
    
    # Проверяем соотношение весов
    ratio_12=$(echo "scale=2; ${server_count[8002]} / ${server_count[8001]}" | bc -l)
    ratio_13=$(echo "scale=2; ${server_count[8003]} / ${server_count[8001]}" | bc -l)
    ratio_23=$(echo "scale=2; ${server_count[8003]} / ${server_count[8002]}" | bc -l)
    
    echo -e "Фактические соотношения:"
    echo -e "  Сервер2/Сервер1: $ratio_12 (ожидается: 1.5)"
    echo -e "  Сервер3/Сервер1: $ratio_13 (ожидается: 2.0)"
    echo -e "  Сервер3/Сервер2: $ratio_23 (ожидается: 1.33)"
    
    # Проверяем, близки ли соотношения к ожидаемым
    if (( $(echo "$ratio_12 >= 1.2 && $ratio_12 <= 1.8" | bc -l) )) && \
       (( $(echo "$ratio_13 >= 1.6 && $ratio_13 <= 2.4" | bc -l) )) && \
       (( $(echo "$ratio_23 >= 1.1 && $ratio_23 <= 1.6" | bc -l) )); then
        echo -e "${GREEN}✓ Взвешенная балансировка работает корректно${NC}"
    else
        echo -e "${YELLOW}⚠ Взвешенная балансировка работает с отклонениями${NC}"
    fi
else
    echo -e "${RED}✗ Обнаружены проблемы с балансировкой${NC}"
    echo -e "  Не все запросы были обработаны успешно"
fi

echo ""
echo -e "${BLUE}=== Рекомендации ===${NC}"
echo "1. Для более точных результатов увеличьте количество запросов"
echo "2. Проверьте логи HAProxy для детальной информации"
echo "3. Убедитесь, что все три backend-сервера работают стабильно"
echo "4. Статистика HAProxy: http://localhost:8404/stats (admin/password)"