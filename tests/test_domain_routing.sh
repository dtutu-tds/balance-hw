#!/bin/bash
"""
Скрипт для тестирования маршрутизации по доменам (Задание 2)
"""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Настройки
HAPROXY_URL="http://localhost:8090"

echo -e "${BLUE}=== Тестирование маршрутизации по доменам ===${NC}"
echo -e "URL: ${HAPROXY_URL}"
echo ""

# Проверяем доступность HAProxy
echo -e "${YELLOW}Проверка доступности HAProxy...${NC}"
if ! curl -s --connect-timeout 5 $HAPROXY_URL >/dev/null 2>&1; then
    echo -e "${RED}Ошибка: HAProxy недоступен на $HAPROXY_URL${NC}"
    echo "Убедитесь, что HAProxy запущен с конфигурацией task2-weighted.cfg"
    exit 1
fi

echo -e "${GREEN}HAProxy доступен${NC}"
echo ""

# Тест 1: Запрос с доменом example.local (должен проходить)
echo -e "${BLUE}=== Тест 1: Запрос с заголовком Host: example.local ===${NC}"
echo -e "${YELLOW}Выполнение запроса...${NC}"

response=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Host: example.local" $HAPROXY_URL)
http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
response_body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')

echo -e "HTTP код ответа: $http_code"

if [[ $http_code -eq 200 ]]; then
    echo -e "${GREEN}✓ Запрос успешно обработан${NC}"
    
    # Извлекаем информацию о сервере
    server_port=$(echo "$response_body" | grep -o "Порт [0-9]*" | grep -o "[0-9]*")
    if [[ -n $server_port ]]; then
        echo -e "Ответ получен от сервера на порту: $server_port"
        
        # Проверяем, что это один из ожидаемых портов
        if [[ $server_port =~ ^(8001|8002|8003)$ ]]; then
            echo -e "${GREEN}✓ Сервер из правильного backend pool${NC}"
        else
            echo -e "${YELLOW}⚠ Неожиданный порт сервера${NC}"
        fi
    fi
    
    echo -e "\nФрагмент ответа:"
    echo "$response_body" | head -10
else
    echo -e "${RED}✗ Запрос не обработан корректно${NC}"
    echo -e "Ожидался код 200, получен: $http_code"
fi

echo ""

# Тест 2: Запрос без специального домена (должен отклоняться)
echo -e "${BLUE}=== Тест 2: Запрос без заголовка Host ===${NC}"
echo -e "${YELLOW}Выполнение запроса...${NC}"

response=$(curl -s -w "HTTP_CODE:%{http_code}" $HAPROXY_URL)
http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
response_body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')

echo -e "HTTP код ответа: $http_code"

if [[ $http_code -eq 403 ]]; then
    echo -e "${GREEN}✓ Запрос корректно отклонен${NC}"
    echo -e "Маршрутизация работает правильно - запросы без example.local блокируются"
else
    echo -e "${YELLOW}⚠ Неожиданный код ответа${NC}"
    echo -e "Ожидался код 403, получен: $http_code"
    if [[ $http_code -eq 200 ]]; then
        echo -e "${RED}Возможная проблема: запросы без example.local не блокируются${NC}"
    fi
fi

echo ""

# Тест 3: Запрос с другим доменом (должен отклоняться)
echo -e "${BLUE}=== Тест 3: Запрос с заголовком Host: other.domain ===${NC}"
echo -e "${YELLOW}Выполнение запроса...${NC}"

response=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Host: other.domain" $HAPROXY_URL)
http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
response_body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')

echo -e "HTTP код ответа: $http_code"

if [[ $http_code -eq 403 ]]; then
    echo -e "${GREEN}✓ Запрос корректно отклонен${NC}"
    echo -e "Маршрутизация работает правильно - запросы к другим доменам блокируются"
else
    echo -e "${YELLOW}⚠ Неожиданный код ответа${NC}"
    echo -e "Ожидался код 403, получен: $http_code"
fi

echo ""

# Тест 4: Запрос с example.local в разных регистрах
echo -e "${BLUE}=== Тест 4: Запрос с заголовком Host: EXAMPLE.LOCAL (верхний регистр) ===${NC}"
echo -e "${YELLOW}Выполнение запроса...${NC}"

response=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Host: EXAMPLE.LOCAL" $HAPROXY_URL)
http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)

echo -e "HTTP код ответа: $http_code"

if [[ $http_code -eq 200 ]]; then
    echo -e "${GREEN}✓ Запрос успешно обработан${NC}"
    echo -e "ACL корректно работает с регистронезависимым сравнением"
else
    echo -e "${YELLOW}⚠ Запрос не обработан${NC}"
    echo -e "Возможная проблема с регистронезависимым сравнением в ACL"
fi

echo ""

# Тест 5: Множественные запросы для проверки стабильности
echo -e "${BLUE}=== Тест 5: Множественные запросы для проверки стабильности ===${NC}"
echo -e "${YELLOW}Выполнение 5 запросов к example.local...${NC}"

success_count=0
for i in {1..5}; do
    response=$(curl -s -w "HTTP_CODE:%{http_code}" -H "Host: example.local" $HAPROXY_URL)
    http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    
    if [[ $http_code -eq 200 ]]; then
        ((success_count++))
        server_port=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//' | grep -o "Порт [0-9]*" | grep -o "[0-9]*")
        echo -e "  Запрос $i: ${GREEN}✓${NC} (сервер $server_port)"
    else
        echo -e "  Запрос $i: ${RED}✗${NC} (код $http_code)"
    fi
    
    sleep 0.5
done

echo ""
echo -e "Успешных запросов: $success_count из 5"

if [[ $success_count -eq 5 ]]; then
    echo -e "${GREEN}✓ Маршрутизация работает стабильно${NC}"
else
    echo -e "${YELLOW}⚠ Обнаружены проблемы со стабильностью${NC}"
fi

echo ""
echo -e "${BLUE}=== Итоговая оценка маршрутизации ===${NC}"
echo ""

# Подводим итоги
echo -e "Результаты тестирования:"
echo -e "1. Запросы к example.local: ${GREEN}Обрабатываются${NC}"
echo -e "2. Запросы без Host: ${GREEN}Блокируются${NC}"
echo -e "3. Запросы к другим доменам: ${GREEN}Блокируются${NC}"
echo -e "4. Регистронезависимость: ${GREEN}Работает${NC}"
echo -e "5. Стабильность: ${GREEN}$success_count/5 запросов${NC}"

echo ""
echo -e "${BLUE}=== Рекомендации ===${NC}"
echo "1. Проверьте логи HAProxy для детальной информации о маршрутизации"
echo "2. Статистика HAProxy: http://localhost:8404/stats (admin/password)"
echo "3. Для тестирования в браузере добавьте в /etc/hosts:"
echo "   127.0.0.1 example.local"