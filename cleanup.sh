#!/bin/bash

# Для работы nexus-cli нужен файл с настройками. Генерим его на лету из переменных
# подставляемых в шаблон и копируем в рабочую директорию.
envsubst '$NEXUS_DOMAIN,$NEXUS_LOGIN,$NEXUS_PASSWORD,$NEXUS_REPO' < CICD/production/nexus-cli/.credentials.template > "$PWD"/.credentials

# Выводим в лог имя удаляемой ветки, чтобы было понятнее.
echo "Cleaning branch: $MR_SOURCE_BRANCH"
echo "-------------------------------"

# Удаляем образы Docker c этим тегом из хранилища Nexus. Берём имя образа без хэша
# коммита, т.к. могут быть несколько образов с одним именем и разными хэшами.
echo "Deleting Nexus images..."
echo "========================"

NEXUS_IMAGES="backend build/base build/builder build/frontend build/upload_artifacts build/upload_artifacts_base nginx postgres rabbitmq service_updater wkhtmltopdf"

get_nexus_tags() {
  nexus-cli image tags -n "$image" | grep "$MR_SOURCE_BRANCH"
}

del_nexus_image() {
  nexus-cli image delete -n "$image" -t "$tag"
}

for image in $NEXUS_IMAGES; do
  for tag in $( get_nexus_tags ); do
    del_nexus_image
  done
done
echo "========================"

# Удаляем релизы и артефакты Sentry через запрос в API.
echo "Deleting Sentry artifacts..."
echo "============================"

SENTRY_AUTH_HEADER="Authorization: Bearer $SENTRY_AUTH_TOKEN"
SENTRY_RELEASES_URL="$SENTRY_URL/api/0/organizations/$SENTRY_ORG/releases"
SENTRY_PAGE_COUNTER=0

# Циклом листаем страницы с релизами и ищем на них нужные имена. При запросе в API мы
# смотрим залоговок запроса и ищем там второе поле 'results'. Пока оно ='true' листаем страницы,
# ищем имена образов и нагребаем их в массив. Потом подставляем его в запрос API для удаления.
get_sentry_page_attr() {
  curl -siH "$SENTRY_AUTH_HEADER" "$SENTRY_RELEASES_URL/?&cursor=100:$SENTRY_PAGE_COUNTER:0" | \
  sed -ne 's/.*results="//' -e 's/".*//p' | \
  grep '[[:alpha:]]'
}

get_sentry_releases() {
  curl -sH "$SENTRY_AUTH_HEADER" "$SENTRY_RELEASES_URL/?&cursor=100:$SENTRY_PAGE_COUNTER:0" | \
  jq -r .[].version | \
  grep "$MR_SOURCE_BRANCH"
}

del_sentry_release() {
  curl -sH "$SENTRY_AUTH_HEADER" "$SENTRY_RELEASES_URL/$release/" -X DELETE
}

# Собираем имена релизов для удаления. Это происходит в цикле листания страницы, пока у неё есть
# нужный атрибут. На последней странице его нет и при выходе из цикла сбор не идёт. Поэтому после
# выхода вызываем ф-ю ещё раз, чтобы не пропустить образы, если они есть на оставшейся странице.
readarray -t SENTRY_RELEASES < <(
  while [[ $( get_sentry_page_attr ) == true ]]; do
      get_sentry_releases
      (( SENTRY_PAGE_COUNTER++ ))
    done
    get_sentry_releases )

for release in "${SENTRY_RELEASES[@]}"; do
  del_sentry_release
  echo "$release"
done
echo "============================"

# Т.к. после сборки и отправки в Nexus локальные образы Docker остаются на сервере, удаляем их.
echo "Deleting local Docker images from Gitlab-Runner..."
echo "=================================================="
docker rmi -f $( docker images | grep "$MR_SOURCE_BRANCH" | tr -s " " | cut -d " " -f 3 ) && \
docker container prune -f && \
docker image prune -f && \
docker system prune -f
echo "=================================================="