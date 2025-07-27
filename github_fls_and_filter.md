# === STEP 1: Upgrade pip and install git-filter-repo ===
python -m pip install --upgrade pip
python -m pip install git-filter-repo

# Add git-filter-repo to PATH for this session (adjust if your Python version/path differs)
$env:Path += ";C:\Users\javier\AppData\Local\Programs\Python\Python312\Scripts"

# === STEP 2: Remove the large file from all commits (force to override clone check) ===
git filter-repo --path iac/aws/finalv2/bin/rpms.tar.gz --invert-paths --force

# === STEP 3: Re-add your origin remote (filter-repo removes remotes) ===
git remote add origin https://github.com/JavierGarAgu/devops-project-v2.git

# === STEP 4: Force push the cleaned history to GitHub ===
git push origin main --force

# === STEP 5: Initialize Git LFS for large file tracking ===
git lfs install

# === STEP 6: Track all .tar.gz files with Git LFS ===
git lfs track "*.tar.gz"

# === STEP 7: Commit the updated .gitattributes file ===
git add .gitattributes
git commit -m "Track .tar.gz files using Git LFS"

# === STEP 8: Re-add the large .tar.gz file (now tracked by LFS) ===
git add iac/aws/finalv2/bin/rpms.tar.gz
git commit -m "Add rpms.tar.gz tracked by Git LFS"

# === STEP 9: Push new commits including LFS-tracked file to GitHub ===
git push origin main
