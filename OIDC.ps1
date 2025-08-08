#script global variables

$PROJECT_ID = Read-Host -Prompt "Enter project ID"
$POOL_ID = Read-Host -Prompt "Enter POOL ID"
$PROVIDER_ID = Read-Host -Prompt "Enter PROVIDER ID"
$GITHUB_REPO = Read-Host -Prompt "Enter GITHUB REPO ID"
$SERVICE_ACCOUNT_NAME = Read-Host -Prompt "Enter SA Name ID"
$PROJECT_NUMBER = (gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
$WIF_PROVIDER = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
$SA_EMAIL = "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

$vars = @(
    "PROJECT_ID = $PROJECT_ID"
    "POOL_ID = $POOL_ID"
    "PROVIDER_ID = $PROVIDER_ID"
    "GITHUB_REPO = $GITHUB_REPO"
    "$SERVICE_ACCOUNT_NAME = $SERVICE_ACCOUNT_NAME"
    "$PROJECT_NUMBER = $PROJECT_NUMBER"


)

foreach ($var in $vars)
{
    Write-Host $var
}

$validate = Read-Host -Prompt "Are these variables are confirmed(Y/N)?"
if($validate = 'Y')
{

gcloud iam workload-identity-pools create $POOL_ID --project $PROJECT_ID --location "global" --display-name "GitHub OIDC Pool"

gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID `
  --project $PROJECT_ID `
  --location="global" `
  --workload-identity-pool=$POOL_ID `
  --display-name="GitHub Provider" `
  --issuer-uri="https://token.actions.githubusercontent.com" `
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" `
  --attribute-condition="attribute.repository=='assertion.repository'"

gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME `
  --project $PROJECT_ID `
  --display-name="Terraform GitHub CI/CD Service Account"


gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
  --project $PROJECT_ID `
  --role "roles/CustomWorkloadIdentityUser" `
  --member "principalSet://iam.googleapis.com/$WIF_PROVIDER/attribute.repository/$GITHUB_REPO"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member "serviceAccount:$SA_EMAIL" `
  --role "roles/owner"

gcloud iam workload-identity-pools providers describe $PROVIDER_ID --workload-identity-pool="$POOL_ID" --location="global"

$member = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/gogo87/CICD_GCP"

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
  --project $PROJECT_ID  `
  --role="roles/iam.workloadIdentityUser" `
  --member $member
 }
 else{
 Write-Host "Exiting the script for variables validation "
 }