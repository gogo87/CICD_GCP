#!/bin/bash

PROJECT_ID=$1
REQUIRED_APIS=("compute.googleapis.com")
ENABLED_APIS=$(gcloud services list --enabled --project="$PROJECT_ID" --format="value(config.name)")

already_enabled=()
just_enabled=()

for api in "${REQUIRED_APIS[@]}"; do
  if echo "$ENABLED_APIS" | grep -q "$api"; then
    already_enabled+=("$api")
  else
    echo "🔧 Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID"
    just_enabled+=("$api")
  fi
done

echo -e "\n✅ Already enabled:"
for api in "${already_enabled[@]}"; do
  echo "  - $api"
done

if [ ${#just_enabled[@]} -gt 0 ]; then
  echo -e "\n✅ Newly enabled:"
  for api in "${just_enabled[@]}"; do
    echo "  - $api"
  done
else
  echo -e "\n🎉 All required APIs were already enabled."
fi