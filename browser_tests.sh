#!/bin/bash

set -x

cd /opt/launcher/
sudo launcher/stop.sh
sudo launcher/pull.sh $IMAGE_TAG
sudo launcher/start.sh -d

cd ~
rm -rf tardis-ui-autotests/
git clone --depth 1 -b tardis-1946_Cover_pilot_test_plan_autotests git@$CI_SERVER_HOST:tardis/tardis-ui-autotests.git
python3 -m venv ~/venv
source ~/venv/bin/activate
cd tardis-ui-autotests/
pip install -r requirements.txt

TIMEOUT_COUNTER=0
until [[ $(curl -skLIw "%{http_code}\\n" $TEST_URL/accounts/login/ -o /dev/null) = 200 ]]; do
  (( TIMEOUT_COUNTER++ ))
  if [[ $TIMEOUT_COUNTER = $TIMEOUT_LIMIT ]]
    then echo "=== Tardis doesn't started properly. Bye then! ===" && \
         cd /opt/launcher/ && \
         ( sudo nohup launcher/stop.sh >/dev/null 2>&1 & ) && \
         exit 1
  fi
  sleep 1
done
echo "=== Tardis has started successfully! ==="

URL=$TEST_URL pytest --browser_name remote --dist=loadscope -n $TEST_THREADS tests
TESTS_EXIT_CODE="$?"

cd /opt/launcher/
sudo nohup launcher/stop.sh >/dev/null 2>&1 &

exit "$TESTS_EXIT_CODE"