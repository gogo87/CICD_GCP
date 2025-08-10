# Clear the screen
Clear-Host

# Script metadata
$scriptVersion = "1.0.0"
$scriptAuthor  = "GoGo"
$scriptDate    = (Get-Date -Format "yyyy-MM-dd")

# Print info
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Workload Identity Federation Setup Script" -ForegroundColor Cyan
Write-Host " Version: $scriptVersion" -ForegroundColor Yellow
Write-Host " Author:  $scriptAuthor" -ForegroundColor Yellow
Write-Host " Date:    $scriptDate" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$letters = @(
    @{Char='G'; Color='Yellow'},
    @{Char='I'; Color='Green'},
    @{Char='T'; Color='Cyan'},
    @{Char='H'; Color='Magenta'},
    @{Char='U'; Color='Red'},
    @{Char='B'; Color='Yellow'},
    @{Char=' '; Color='White'},
    @{Char='→'; Color='Cyan'},
    @{Char=' '; Color='White'},
    @{Char='G'; Color='Yellow'},
    @{Char='C'; Color='Magenta'},
    @{Char='P'; Color='Red'},
    @{Char=' '; Color='White'},
    @{Char='O'; Color='Yellow'},
    @{Char='I'; Color='Green'},
    @{Char='D'; Color='Cyan'},
    @{Char='C'; Color='Magenta'},
    @{Char=' '; Color='White'},
    @{Char='B'; Color='Red'},
    @{Char='R'; Color='Yellow'},
    @{Char='I'; Color='Green'},
    @{Char='D'; Color='Cyan'},
    @{Char='G'; Color='Magenta'},
    @{Char='E'; Color='Red'}
)

foreach ($letter in $letters) {
    Write-Host -NoNewline $letter.Char -ForegroundColor $letter.Color
}
Write-Host ""

#script global variables

$PROJECT_ID = Read-Host -Prompt "Enter project ID"
$POOL_ID = Read-Host -Prompt "Enter POOL ID"
$PROVIDER_ID = Read-Host -Prompt "Enter PROVIDER ID"
$GITHUB_REPO = Read-Host -Prompt "Enter GITHUB REPO ID"
$SERVICE_ACCOUNT_NAME = Read-Host -Prompt "Enter SA Name ID"
$PROJECT_NUMBER = (gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
#$WIF_PROVIDER = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
$SA_EMAIL = "$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
$MEMBER = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_REPO"
$API = "iamcredentials.googleapis.com"
$vars = @(
    "PROJECT_ID = $PROJECT_ID"
    "POOL_ID = $POOL_ID"
    "PROVIDER_ID = $PROVIDER_ID"
    "GITHUB_REPO = $GITHUB_REPO"
    "SERVICE_ACCOUNT_NAME = $SERVICE_ACCOUNT_NAME"
    "PROJECT_NUMBER = $PROJECT_NUMBER"
)

foreach ($var in $vars)
{
    Write-Host $var
}

function Connect-GCP {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectId
    )

    Write-Host "Choose authentication method:" -ForegroundColor Cyan
    Write-Host "  1) Browser OAuth (recommended)" -ForegroundColor Yellow
    Write-Host "  2) Device Flow (no browser pop-up on this machine)" -ForegroundColor Yellow
    Write-Host "  3) Service Account JSON (provide key file)" -ForegroundColor Yellow
    $choice = Read-Host "Enter 1 / 2 / 3"

    switch ($choice) {
        '1' {
            Write-Host "Starting browser OAuth login..." -ForegroundColor Green
            gcloud auth login --update-adc | Out-Null
        }
        '2' {
            Write-Host "Starting device flow login..." -ForegroundColor Green
            gcloud auth login --no-launch-browser --update-adc | Out-Null
            Write-Host "Follow the instructions shown in the terminal to complete login." -ForegroundColor Cyan
        }
        '3' {
            $keyPath = Read-Host "Enter full path to Service Account key JSON"
            if (-not (Test-Path $keyPath)) { throw "Key file not found: $keyPath" }
            Write-Host "Activating service account from key..." -ForegroundColor Green
            gcloud auth activate-service-account --key-file="$keyPath" --project="$ProjectId" | Out-Null
            # Make it the ADC for SDKs/Terraform
            $env:GOOGLE_APPLICATION_CREDENTIALS = $keyPath
        }
        default {
            throw "Invalid choice. Please run again and pick 1, 2, or 3."
        }
    }

    # Set project & verify access
    gcloud config set project "$ProjectId" | Out-Null

    # Quick permission sanity check
    try {
        $pn = gcloud projects describe "$ProjectId" --format="value(projectNumber)"
        if (-not $pn) { throw "Unable to read project: $ProjectId" }
        Write-Host "Authenticated. Project set to $ProjectId (Project Number: $pn)" -ForegroundColor Green
    } catch {
        throw "Authentication succeeded but permission check failed: $($_.Exception.Message)"
    }
}

Connect-GCP -ProjectId $PROJECT_ID

# get enabled services
$enabled = gcloud services list --enabled --project $PROJECT_ID --format="value(config.name)" 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to list enabled services for project '$PROJECT_ID'. Ensure you are authenticated and the project exists."
}

if ($enabled -and ($enabled -contains $api)) {
    Write-Host "'$API' is already enabled on project '$PROJECT_ID'."
}else{

Write-Host "'$API' is NOT enabled on project '$PROJECT_ID'. Enabling now..."
gcloud services enable $API --project $PROJECT_ID

if ($LASTEXITCODE -eq 0) {
    Write-Host "Enabled '$API' successfully."
    
}
}

Write-Host "== Creating Workload Identity Pool ==" -ForegroundColor Cyan

gcloud iam workload-identity-pools create $POOL_ID --project $PROJECT_ID --location "global" --display-name "GitHub OIDC Pool"

Write-Host "== Creating OIDC Provider ==" -ForegroundColor Cyan

gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID `
  --project $PROJECT_ID `
  --location="global" `
  --workload-identity-pool=$POOL_ID `
  --display-name="GitHub Provider" `
  --issuer-uri="https://token.actions.githubusercontent.com" `
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" `
  --attribute-condition="attribute.repository==assertion.repository"

  Write-Host "== Creating Service Account ==" -ForegroundColor Cyan

gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME `
  --project $PROJECT_ID `
  --display-name="Terraform GitHub CI/CD Service Account"

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
  --project $PROJECT_ID `
  --role="roles/iam.workloadIdentityUser" `
  --member $MEMBER

Write-Host "== Grant service account OWNER on project (be careful) ==" -ForegroundColor Cyan

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member "serviceAccount:$SA_EMAIL" `
  --role "roles/owner"

Write-Host "== Allow GitHub repo to impersonate the service account via WIF (workloadIdentityUser) ==" -ForegroundColor Cyan

gcloud iam workload-identity-pools providers describe $PROVIDER_ID --workload-identity-pool="$POOL_ID" --location="global"

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
  --project $PROJECT_ID  `
  --role="roles/iam.workloadIdentityUser" `
  --member $MEMBER