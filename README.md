
# Django Project README

## О проекте

Этот репозиторий содержит Django-проект. Следуйте инструкциям ниже для корректного развертывания и запуска приложения на вашей машине.

---

## 1. Клонирование репозитория

git clone https://github.com/vitobrat/msp_course_work.git;

cd db_admin;

---

## 2. Создание виртуального окружения

**Windows:**
python -m venv venv

venv\Scripts\activate

**Linux / macOS:**
python3 -m venv venv

source venv/bin/activate

---

## 3. Установка зависимостей

Убедитесь, что файл `requirements.txt` находится в корне проекта.

pip install -r requirements.txt


---

## 4. Применение миграций

python manage.py migrate

---

## 5. (Опционально) Создание суперпользователя

python manage.py createsuperuser

---

## 6. Запуск сервера разработки

python manage.py runserver

Перейдите по адресу [http://127.0.0.1:8000/](http://127.0.0.1:8000/) в браузере.

---

## 9. Основные команды Django

| Команда                                 | Описание                                 |
|------------------------------------------|------------------------------------------|
| `python manage.py makemigrations`        | Создать файлы миграций                   |
| `python manage.py migrate`               | Применить миграции                       |
| `python manage.py createsuperuser`       | Создать суперпользователя                |
| `python manage.py runserver`             | Запустить сервер разработки              |


---

## 10. Дополнительно

- Документацию смотрите на [docs.djangoproject.com](https://docs.djangoproject.com/ru/stable/)
- Не забудьте активировать виртуальное окружение при каждом старте работы!

---

**Кратко:**  
1. Клонируйте проект  
2. Создайте и активируйте виртуальное окружение  
3. Установите зависимости  
4. Примените миграции  
5. (Создайте суперпользователя)  
6. Запустите сервер разработки

---

**Если возникнут вопросы — смотрите документацию Django или пишите мне!**
