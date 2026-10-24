#!/bin/bash
# ================== VARIABLES ==================
export PROJECT_ID=qwiklabs-gcp-03-79d5ad49d11f
export REGION=us-central1
export ZONE=us-central1-a
USER1="student-03-bbed2d9d7202@qwiklabs.net"
USER2="student-03-9e59c775b27e@qwiklabs.net"
BUCKET="${PROJECT_ID}-iam-bucket"
SA_NAME="read-bucket-objects"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# ================== RETRY FUNCTION ==================
retry() {
  local n=1 max=20 delay=10
  until "$@"; do
    if (( n >= max )); then
      echo "❌ $max attempts ke baad bhi fail: $*"
      return 1
    fi
    echo "⚠️  Attempt $n fail hua, ${delay}s baad retry..."
    ((n++)); sleep $delay
  done
}

# ================== TASK 3: BUCKET + FILE ==================
echo "=== TASK 3: Bucket + sample.txt ==="
retry gcloud services enable compute.googleapis.com storage.googleapis.com iam.googleapis.com

gcloud storage buckets describe gs://$BUCKET >/dev/null 2>&1 || \
  retry gcloud storage buckets create gs://$BUCKET --location=US --project=$PROJECT_ID

echo "This is a sample file" > sample.txt
retry gcloud storage cp sample.txt gs://$BUCKET/sample.txt

# ================== TASK 4: USER2 KA ACCESS REMOVE ==================
echo "=== TASK 4: Username 2 ka project access remove ==="
for ROLE in $(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:user:$USER2" \
    --format="value(bindings.role)"); do
  retry gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member="user:$USER2" --role="$ROLE" --quiet >/dev/null
done

# ================== TASK 5: USER2 KO STORAGE OBJECT VIEWER ==================
echo "=== TASK 5: Username 2 ko Storage Object Viewer ==="
retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER2" --role="roles/storage.objectViewer" --quiet >/dev/null

# ================== TASK 6: SERVICE ACCOUNT + VM ==================
echo "=== TASK 6: Service account ==="
gcloud iam service-accounts describe $SA_EMAIL >/dev/null 2>&1 || \
  retry gcloud iam service-accounts create $SA_NAME --display-name="$SA_NAME"

# SA ko Storage Object Viewer role (project level)
retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" --role="roles/storage.objectViewer" --quiet >/dev/null

# altostrat.com ko Service Account User role (is SA par)
retry gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --member="domain:altostrat.com" --role="roles/iam.serviceAccountUser" --quiet >/dev/null

# altostrat.com ko Compute Instance Admin (v1)
retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="domain:altostrat.com" --role="roles/compute.instanceAdmin.v1" --quiet >/dev/null

echo "=== VM demoiam create ==="
gcloud compute instances describe demoiam --zone=$ZONE >/dev/null 2>&1 || \
  retry gcloud compute instances create demoiam \
    --zone=$ZONE \
    --machine-type=e2-micro \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --service-account=$SA_EMAIL \
    --scopes=https://www.googleapis.com/auth/devstorage.read_write

# ================== TASK 7: SERVICE ACCOUNT USER EXPLORE ==================
echo "=== TASK 7: VM par SSH se test ==="
# SSH ke liye VM boot hone do
sleep 40

# (a) instances list -> "insufficient authentication scopes" warning aana EXPECTED hai
gcloud compute ssh demoiam --zone=$ZONE --quiet --command="gcloud compute instances list" || true

# (b) bucket se file copy (kaam karni chahiye)
retry gcloud compute ssh demoiam --zone=$ZONE --quiet \
  --command="gcloud storage cp gs://$BUCKET/sample.txt . && mv sample.txt sample2.txt"

# (c) wapas upload -> 403 AccessDenied aana EXPECTED hai
gcloud compute ssh demoiam --zone=$ZONE --quiet \
  --command="gcloud storage cp sample2.txt gs://$BUCKET" || true

# (d) SA ka role Viewer -> Object Creator
retry gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" --role="roles/storage.objectViewer" --quiet >/dev/null
retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" --role="roles/storage.objectCreator" --quiet >/dev/null

# (e) Ab upload dobara try (IAM propagate hone mein time lagta hai, isliye retry)
echo "=== Role change ke baad upload retry ==="
retry gcloud compute ssh demoiam --zone=$ZONE --quiet \
  --command="gcloud storage cp sample2.txt gs://$BUCKET"

echo "✅ Sab tasks complete! Ab Google Skills page par 'Check my progress' click karo."
