#!/bin/bash -ex

if [[ "${TRAVIS_EVENT_TYPE}" == "push" && "${TRAVIS_BRANCH}" == "develop" && "${TRAVIS_REPO_SLUG}" == "scalikejdbc/scalikejdbc.github.io" ]]; then
  openssl version
  echo -e "Host github.com\n\tStrictHostKeyChecking no\nIdentityFile ~/.ssh/scalikejdbc-website-key\n" >> ~/.ssh/config
  openssl aes-256-cbc -K $encrypted_ceeb064f972d_key -iv $encrypted_ceeb064f972d_iv -in .travis/deploy_rsa.enc -out scalikejdbc-website-key -d
  chmod 600 scalikejdbc-website-key
  mv scalikejdbc-website-key ~/.ssh/
  git config --global user.email "seratch@gmail.com"
  git config --global user.name "Kaz Sera"
  mv build ../
  git fetch origin master:master
  git clean -fdx
  git checkout master
  rm -rf ./*
  cp -r ../build/* ./
  git add .
  git commit -a -m "auto commit on travis https://github.com/scalikejdbc/scalikejdbc.github.io/commit/${TRAVIS_COMMIT} ${TRAVIS_JOB_NUMBER}"
  git diff HEAD^
  git push git@github.com:scalikejdbc/scalikejdbc.github.io.git master:master
fi
