# Лабораторная 2: очистка данных и удалённая классификация

Комплект использует два ноутбука и два Docker-контейнера. Узел А очищает CSV и передаёт его на узел Б по SSH/SCP. Узел Б обучает `DecisionTreeClassifier`; ноутбук А запрашивает результат у Flask через HTTP.

## Быстрый запуск на одном компьютере

Этот сценарий проверяет очистку CSV, передачу по SSH и ответ классификатора через HTTP в Docker. Из корня проекта выполните:

```bash
sh scripts/prepare_local_docker.sh
docker compose -f compose.local.yaml up --build -d
docker compose -f compose.local.yaml exec data-processor-local python /app/process_and_request.py
```

При успехе ответ содержит `"status": "success"`, 120 строк обучения и 30 прогнозов. Остановить контейнеры:

```bash
docker compose -f compose.local.yaml down
```

Проверка связи между физическими ноутбуками описана ниже.

## Состав

- `node_a/data_processor.ipynb` — управление контейнером очистки, передача CSV и запрос `/predict`.
- `node_a/process_and_request.py` — очистка, SSH/SCP и вызов API внутри контейнера `data-processor`.
- `node_b/ml_trainer.ipynb` — управление контейнером `ml-trainer` и просмотр ответа.
- `node_b/ml_service.py` — разбиение данных 80/20, обучение дерева и Flask API.

Зависимости закреплены для Python 3.9: pandas 2.2.3, scikit-learn 1.6.1, Flask 3.1.3. Scikit-learn 1.6 поддерживает Python 3.9; Flask 3.1 поддерживает Python 3.9 и новее. [Scikit-learn](https://scikit-learn.org/1.9/install.html) · [Flask](https://flask.palletsprojects.com/en/stable/installation/)

## 1. Подготовить ноутбуки

Оба ноутбука должны быть в одной Wi-Fi сети. Проверьте адреса командой `ip a` и связь в обе стороны командой `ping`. Отключите AP Isolation на роутере. Установите Docker Engine и Docker Compose v2 на оба устройства.

Скопируйте этот проект на оба ноутбука. Узел Б будет принимать файл в `node_b/data`; создайте каталог и узнайте его абсолютный путь:

```bash
mkdir -p node_b/data
realpath node_b/data
```

## 2. Настроить SSH

По требованиям лабораторной установите и запустите SSH-сервер на обоих ноутбуках (для передачи А→Б входящее SSH-соединение обязательно на Б). Примените настройки на обоих:

```text
PermitRootLogin no
MaxAuthTries 3
```

Проверьте конфигурацию и перезапустите службу:

```bash
sudo sshd -t
sudo systemctl restart ssh
sudo systemctl status ssh
```

На ноутбуке А создайте ключ и добавьте его публичную часть в аккаунт пользователя Б:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab2_ed25519
ssh-copy-id -i ~/.ssh/lab2_ed25519.pub <USER_B>@<IP_B>
ssh -i ~/.ssh/lab2_ed25519 <USER_B>@<IP_B> true
```

При первом подключении сверьте отпечаток SSH-хоста Б. Не копируйте приватный ключ в проект и никому его не отправляйте.

## 3. Настроить узел Б

Из папки `node_b` скопируйте пример окружения и запустите сервер:

```bash
cd node_b
cp .env.example .env
docker compose up --build -d
docker ps --filter name=ml-trainer
curl http://127.0.0.1:5000/health
```

Сервер слушает `0.0.0.0:5000`. `data_ready: false` ожидаем до передачи CSV с узла А.

## 4. Настроить узел А

Скопируйте `node_a/.env.example` в `node_a/.env`. Укажите IP-адрес и пользователя Б, абсолютный путь `node_b/data` на ноутбуке Б, локальный каталог `.ssh` и имя созданного ключа:

```dotenv
NODE_B_HOST=<IP_B>
NODE_B_USER=<USER_B>
NODE_B_DATA_DIR=<ABSOLUTE_PATH_TO_NODE_B_DATA>
SSH_DIR=<ABSOLUTE_PATH_TO_A_SSH_DIRECTORY>
SSH_KEY_FILE=lab2_ed25519
SSH_PORT=22
TARGET_COLUMN=species
USE_IRIS_FALLBACK=true
```

Путь `SSH_DIR` монтируется в контейнер только для чтения. В нём должны быть приватный ключ и `known_hosts`. Контейнер требует заранее проверенную запись хоста Б и не отключает проверку SSH-отпечатка.

Если преподаватель выдал размеченный CSV, поместите его как `node_a/data/raw_data.csv`, установите правильное имя целевого столбца в `TARGET_COLUMN` и оставьте `USE_IRIS_FALLBACK=true`. Если файла нет, скрипт создаст учебный CSV из Iris и целевой столбец `species`.

## 5. Запустить узел А

Из папки `node_a`:

```bash
cd node_a
cp .env.example .env
docker compose up --build -d
docker exec data-processor sh -lc 'ping -c 4 "$NODE_B_HOST"'
docker exec data-processor python /app/process_and_request.py
```

Скрипт удаляет полностью пустые и неполные строки, обрезает пробелы и переводит текстовые поля в нижний регистр. Затем он копирует `clean_data.csv` в `node_b/data` по SSH/SCP и запрашивает `GET http://<IP_B>:5000/predict` командой `curl`.

Успешный `ping` проверяет доступность ноутбука Б по ICMP. Проверка `curl` в следующей команде проверяет именно Flask и TCP-порт 5000.

То же действие выполняет ноутбук `node_a/data_processor.ipynb`. Ноутбук Б показывает запуск сервера и ответ в `node_b/ml_trainer.ipynb`.

## 6. Ограничить доступ к порту 5000

На узле Б после запуска Docker проверьте цепочку `DOCKER-USER` и добавьте правила в указанном порядке. Установите `iptables-persistent`, если `netfilter-persistent` ещё не установлен (`sudo apt install iptables-persistent`). Замените `<IP_A>` адресом Wi-Fi-интерфейса ноутбука А:

```bash
sudo iptables -I DOCKER-USER 1 -s <IP_A> -p tcp --dport 5000 -j ACCEPT
sudo iptables -I DOCKER-USER 2 -p tcp --dport 5000 -j DROP
sudo iptables -nvL DOCKER-USER --line-numbers
```

Сохраните правила для перезагрузки:

```bash
sudo netfilter-persistent save
```

Проверьте с узла А:

```bash
curl http://<IP_B>:5000/health
curl http://<IP_B>:5000/predict
```

Проверьте с другого устройства, что порт 5000 недоступен. Не запускайте правила повторно без проверки текущего порядка: дубли могут изменить доступ.

## API

- `GET /health` возвращает статус Flask и наличие `clean_data.csv`.
- `GET /predict` обучает дерево на 80% размеченных строк и возвращает прогнозы для 20% проверочных строк.
- Успешный ответ содержит `status`, `target_column`, `train_rows`, `test_rows`, `accuracy` и массив `predictions`. `row_index` отсчитывается с нуля в очищенном CSV.

Без целевого столбца модель классификации не обучится. Для учебного Iris целевой столбец — `species`.

## Ограничение проверки

Проверка реального Wi-Fi, SSH, Docker NAT и firewall требует двух физических ноутбуков. Выполните сетевые команды на устройствах; этот проект не меняет SSH- или iptables-настройки автоматически.

## Локальная проверка в Docker на одном компьютере

Этот режим поднимает два контейнера в одной Docker-сети. Контейнер Б запускает и SSH-сервер, и Flask; контейнер А передаёт ему CSV по SCP и запрашивает прогноз по HTTP. Для этого режима SSH-сервер на компьютере устанавливать не нужно. Он проверяет весь программный маршрут, но не Wi-Fi между ноутбуками и не правила firewall для разных физических устройств.

Нужны Docker Compose v2 и `ssh-keygen` на компьютере. Из корня проекта выполните:

```bash
sh scripts/prepare_local_docker.sh
docker compose -f compose.local.yaml up --build -d
docker compose -f compose.local.yaml exec data-processor-local python /app/process_and_request.py
```

Для теста используется Iris, если `node_a/data/raw_data.csv` отсутствует. Ожидаемый результат — 120 строк обучения и 30 прогнозов. Flask доступен с самого компьютера по адресу `http://127.0.0.1:5000/health`; запрос из контейнера А использует внутреннее имя `ml-trainer-local`.

Остановить контейнеры можно командой:

```bash
docker compose -f compose.local.yaml down
```

Ключи локального теста создаются в `.local-docker/` и исключены из Git. Не переносите этот локальный режим в сдаваемую конфигурацию двух ноутбуков: для неё оставлены отдельные Compose-файлы в `node_a` и `node_b`.
