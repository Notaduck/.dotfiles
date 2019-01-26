#!/usr/bin/env bash
CURRENT_PATH=${PWD};

for script in `ls .`;
do
	(sudo ln -sf ${CURRENT_PATH}/${script} /usr/local/bin/${script})
	(sudo chmod +x /usr/local/bin/${script})
done
