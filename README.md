# setup_dev_env.sh

> Репозиторий: [github.com/shams4km/bash-dev-setup](https://github.com/shams4km/bash-dev-setup)

Bash-скрипт для автоматической настройки рабочего окружения разработчиков на Linux-сервере.

---

## Задание

- Создать группу `dev` и добавить в неё всех «не системных» пользователей (UID ≥ 1000).
- Выдать группе `dev` права sudo без запроса пароля.
- Для каждого пользователя создать директорию `<user_name>_workdir`.
- Путь до директорий задаётся ключом `-d`; если ключ не передан — запрашивается в интерактивном режиме.
- Директории создаются с правами `660` (владелец — пользователь, группа — основная группа пользователя).
- Группе `dev` через ACL выдаётся право **чтения** на каждую директорию.
- Весь лог дублируется в `stdout` **и** в файл `/var/log/setup_dev_env.log`.

---

## Запуск

```bash
# с явным указанием пути
sudo bash setup_dev_env.sh -d /home/workdirs

# без ключа -d (путь будет запрошен интерактивно)
sudo bash setup_dev_env.sh
```

> Скрипт требует прав **root**. Пакет `acl` должен быть установлен (`apt install acl` / `yum install acl`).

---

## Что делает скрипт — пошагово

| Шаг | Действие |
|-----|----------|
| 1 | Проверяет, что запущен от root |
| 2 | Разбирает аргументы (`-d PATH`), при необходимости запрашивает путь |
| 3 | Создаёт группу `dev` (если не существует) |
| 4 | Находит всех не системных пользователей (`UID 1000–65533` из `/etc/passwd`) |
| 5 | Добавляет каждого из них в группу `dev` через `usermod -aG` |
| 6 | Записывает правило `%dev ALL=(ALL) NOPASSWD: ALL` в `/etc/sudoers.d/dev_nopasswd` и проверяет его через `visudo -c` |
| 7 | Создаёт `<BASE_DIR>/<user>_workdir` для каждого пользователя |
| 8 | Выставляет `chown user:usergroup` + `chmod 660` |
| 9 | Добавляет ACL-запись `g:dev:r-x` через `setfacl` |
| 10 | Все события логирует через `tee` в stdout и `/var/log/setup_dev_env.log` |

---

## Результат выполнения

Тест запускался в контейнере Ubuntu 22.04 с тремя тестовыми пользователями: `alice`, `bob`, `carol`.

### 1. Запуск скрипта

```bash
sudo bash setup_dev_env.sh -d /home/workdirs
```

```
[2026-05-23 13:19:58] === setup_dev_env.sh started ===
[2026-05-23 13:19:58] Base directory: /home/workdirs
[2026-05-23 13:19:58] Group 'dev' created.
[2026-05-23 13:19:58] User 'alice' added to group 'dev'.
[2026-05-23 13:19:58] User 'bob' added to group 'dev'.
[2026-05-23 13:19:58] User 'carol' added to group 'dev'.
/etc/sudoers.d/dev_nopasswd: parsed OK
[2026-05-23 13:19:58] Sudoers rule written: /etc/sudoers.d/dev_nopasswd
[2026-05-23 13:19:58] Base directory '/home/workdirs' created.
[2026-05-23 13:19:58] Directory '/home/workdirs/alice_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: alice  group: alice
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/alice_workdir'.
[2026-05-23 13:19:58] Directory '/home/workdirs/bob_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: bob  group: bob
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/bob_workdir'.
[2026-05-23 13:19:58] Directory '/home/workdirs/carol_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: carol  group: carol
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/carol_workdir'.
[2026-05-23 13:19:58] === setup_dev_env.sh finished successfully ===
[2026-05-23 13:19:58] Log file: /var/log/setup_dev_env.log
```

---

### 2. Пользователи в группе dev

```bash
getent group dev
```

```
dev:x:1003:alice,bob,carol
```

Все три не системных пользователя добавлены в группу `dev`.

---

### 3. Sudoers-правило

```bash
cat /etc/sudoers.d/dev_nopasswd
```

```
%dev ALL=(ALL) NOPASSWD: ALL
```

---

### 4. Права на директории

```bash
ls -la /home/workdirs/
```

```
total 20
drwxr-xr-x  5 root  root  4096 May 23 13:19 .
drwxr-xr-x  1 root  root  4096 May 23 13:19 ..
drw-rwx---+ 2 alice alice 4096 May 23 13:19 alice_workdir
drw-rwx---+ 2 bob   bob   4096 May 23 13:19 bob_workdir
drw-rwx---+ 2 carol carol 4096 May 23 13:19 carol_workdir
```

Права `660`, владелец и группа соответствуют пользователю. Знак `+` означает наличие ACL.

---

### 5. ACL на директории

```bash
getfacl /home/workdirs/alice_workdir
```

```
# file: home/workdirs/alice_workdir
# owner: alice
# group: alice
user::rw-
group::rw-
group:dev:r-x
mask::rwx
other::---
```

Группа `dev` имеет право чтения (`r-x`) через ACL.

---

### 6. Лог-файл

```bash
cat /var/log/setup_dev_env.log
```

```
[2026-05-23 13:19:58] === setup_dev_env.sh started ===
[2026-05-23 13:19:58] Base directory: /home/workdirs
[2026-05-23 13:19:58] Group 'dev' created.
[2026-05-23 13:19:58] User 'alice' added to group 'dev'.
[2026-05-23 13:19:58] User 'bob' added to group 'dev'.
[2026-05-23 13:19:58] User 'carol' added to group 'dev'.
[2026-05-23 13:19:58] Sudoers rule written: /etc/sudoers.d/dev_nopasswd
[2026-05-23 13:19:58] Base directory '/home/workdirs' created.
[2026-05-23 13:19:58] Directory '/home/workdirs/alice_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: alice  group: alice
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/alice_workdir'.
[2026-05-23 13:19:58] Directory '/home/workdirs/bob_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: bob  group: bob
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/bob_workdir'.
[2026-05-23 13:19:58] Directory '/home/workdirs/carol_workdir' created.
[2026-05-23 13:19:58]   permissions: 660  owner: carol  group: carol
[2026-05-23 13:19:58]   ACL: group 'dev' granted read+execute on '/home/workdirs/carol_workdir'.
[2026-05-23 13:19:58] === setup_dev_env.sh finished successfully ===
[2026-05-23 13:19:58] Log file: /var/log/setup_dev_env.log
```

Лог полностью дублируется в файл параллельно с выводом в stdout.

---

## Проверка результата

```bash
# убедиться, что пользователи в группе dev
getent group dev

# проверить sudoers-файл
sudo visudo -cf /etc/sudoers.d/dev_nopasswd

# посмотреть права директорий
ls -la /home/workdirs/

# посмотреть ACL
getfacl /home/workdirs/alice_workdir

# посмотреть лог
cat /var/log/setup_dev_env.log
```

---

## Требования

- Linux (тестировалось на Ubuntu 22.04)
- Bash ≥ 4.0
- Пакет `acl` (`apt install acl`)
- Права root / sudo

---

## Структура репозитория

```
.
├── setup_dev_env.sh   # основной скрипт
└── README.md          # документация
```
