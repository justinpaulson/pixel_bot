#!/bin/bash

# Configuration
REPOSITORY_NAME="pixel"
REGISTRY_NAME="justinpaulson"
KEEP_IMAGES_COUNT=3

doctl auth init --access-token $KAMAL_REGISTRY_PASSWORD

# Check if the "commit" argument is provided
DRY_RUN=true
if [[ $1 == "commit" ]]; then
  DRY_RUN=false
  echo "Running in commit mode. Images will be deleted."
else
  echo "Dry run mode. No images will be deleted."
fi

# Fetch all image manifests sorted by date (oldest to newest)
echo "Fetching image manifests for repository: $REPOSITORY_NAME"
manifest_list=$(doctl registry repository list-manifests "$REPOSITORY_NAME" --format Digest,UpdatedAt --no-header | sort -k2)

# Count total manifests
total_manifests=$(echo "$manifest_list" | wc -l)

if [[ $total_manifests -le $KEEP_IMAGES_COUNT ]]; then
  echo "Total images ($total_manifests) is less than or equal to KEEP_IMAGES_COUNT ($KEEP_IMAGES_COUNT). No deletion needed."
  exit 0
fi

# Calculate how many manifests to delete
manifests_to_delete=$((total_manifests - KEEP_IMAGES_COUNT))

echo "Total images: $total_manifests, keeping the latest $KEEP_IMAGES_COUNT images."
echo "Preparing to delete $manifests_to_delete old images..."

# Perform deletion for each manifest to delete
counter=0
echo "$manifest_list" | while IFS= read -r line; do
  if [[ $counter -lt $manifests_to_delete ]]; then
    digest=$(echo "$line" | awk '{print $1}')
    if [[ $DRY_RUN == true ]]; then
      echo "[Dry Run] Would delete manifest with digest: $digest"
    else
      echo "Deleting manifest with digest: $digest"
      doctl registry repository delete-manifest "$REPOSITORY_NAME" "$digest" --force
    fi
    ((counter++))
  else
    break
  fi
done

if [[ $DRY_RUN == true ]]; then
  echo "Dry run complete. No images were deleted."
else
  echo "Cleanup complete. Kept the latest $KEEP_IMAGES_COUNT images."

  echo "Would you like to run garbage collection? (y/n)"
  read -r run_gc
  if [[ $run_gc == "y" ]]; then
    echo "Running garbage collection..."
    doctl registry garbage-collection start --force
  fi
fi
