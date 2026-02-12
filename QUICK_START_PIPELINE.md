# 🚀 Guide Rapide - Lancement du Pipeline

## ✅ **Tous les outils sont installés et prêts!**

```bash
✓ Docker:    29.1.5
✓ Terraform: 1.9.8
✓ Ansible:   2.16.3
✓ Trivy:     0.50.0
✓ kubectl:   1.34.4
✓ SSH Key:   ~/.ssh/ai-product-insights-key.pem
```

---

## 🧪 **Option 1 : Test LOCAL (Sans Jenkins)**

### **Déploiement complet sur AWS EC2**

```bash
cd /home/saif/projects/Product_Insights

# Export des credentials
export AWS_ACCESS_KEY_ID="votre-key-id"
export AWS_SECRET_ACCESS_KEY="votre-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
export GEMINI_API_KEY="votre-gemini-key"

# Lancer le pipeline localement
./test-pipeline-locally.sh
```

**Ce script fera automatiquement :**
1. ✅ Vérification des prérequis
2. ✅ Terraform init + plan + apply (création VPC, EC2)
3. ✅ Extraction de l'IP publique EC2
4. ✅ Mise à jour de l'inventory Ansible
5. ✅ Attente que l'instance soit prête (60s)
6. ✅ Ansible playbook (installation Docker, déploiement)
7. ✅ Affichage des URLs

**Résultat attendu :**
```
✅ DEPLOYMENT SUCCESSFUL!
🌐 Frontend URL: http://34.xxx.xxx.xxx
📡 Backend API: http://34.xxx.xxx.xxx:8000
```

### **Nettoyage après test**
```bash
cd infrastructure/terraform
terraform destroy -var-file=terraform.tfvars -auto-approve
```

---

## 🎯 **Option 2 : Pipeline JENKINS (Production)**

### **Prérequis Jenkins (à faire une seule fois)**

#### **1. Créer les Credentials dans Jenkins**

Jenkins → Manage Jenkins → Credentials → Add Credentials

| ID | Type | Valeur |
|----|------|--------|
| `dockerhub-credentials` | Username + Password | saifdine23 + [token] |
| `aws-access-key-id` | Secret text | AKIA... |
| `aws-secret-access-key` | Secret text | G+CuKf... |
| `gemini-api-key` | Secret text | AIzaSy... |

#### **2. Créer le Pipeline Job**

```
Jenkins → New Item → Pipeline
Name: ai-product-insights-pipeline

Configuration:
  - GitHub project: https://github.com/SAIFDINE23/ai-product-insights-platform
  - Pipeline from SCM
  - Git: https://github.com/SAIFDINE23/ai-product-insights-platform
  - Branch: */main
  - Script Path: Jenkinsfile
```

#### **3. Copier la clé SSH (si Jenkins tourne sous user jenkins)**

```bash
sudo su - jenkins
mkdir -p ~/.ssh
cp /home/saif/.ssh/ai-product-insights-key.pem ~/.ssh/
chmod 600 ~/.ssh/ai-product-insights-key.pem
exit
```

---

### **Lancer le Pipeline Jenkins**

#### **Déclenchement Automatique (Git Push)**
```bash
git add .
git commit -m "deploy: trigger pipeline"
git push origin main
# → Jenkins se déclenche automatiquement
```

#### **Déclenchement Manuel**

1. Jenkins → ai-product-insights-pipeline → **Build with Parameters**
2. Sélectionner les paramètres :
   - `ACTION`: `Build & Push & Deploy AWS`
   - `DEPLOY_TARGET`: `aws-ec2`
   - `IMAGE_TAG`: `latest`
   - `PUSH_TO_REGISTRY`: ✅ true
   - `SCAN_WITH_TRIVY`: ✅ true
   - `TERRAFORM_DESTROY`: ❌ false (ou ✅ true pour cleanup auto)
3. **Build**

---

## 📊 **Stages du Pipeline Jenkins**

```
Stage 1: 🔄 Checkout                    → Clone le repo
Stage 2: ✓ Verify Prerequisites         → Vérifie les outils
Stage 3: 🔨 Build Docker Images         → Build 4 images en parallèle
Stage 4: 🔍 Security Scan (Trivy)       → Scan de sécurité
Stage 5: 📤 Push to Registry            → Push vers DockerHub
Stage 6: 🚀 Deploy to Kubernetes        → (Optionnel - déjà testé hier)
Stage 7: 🏗️ Terraform - Provision AWS   → Création infrastructure
Stage 8: 📦 Ansible - Deploy to AWS     → Déploiement application
Stage 9: 🗑️ Terraform Destroy           → (Optionnel - cleanup)
```

---

## ⚡ **Commandes Rapides**

### **Test rapide Terraform uniquement**
```bash
cd infrastructure/terraform
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

### **Test rapide Ansible uniquement (après Terraform)**
```bash
cd infrastructure/ansible
export EC2_PUBLIC_IP=$(cd ../terraform && terraform output -raw instance_public_ip)

# Mettre à jour l'inventory
cat > inventory.ini <<EOF
[ec2_instances]
ec2-app ansible_host=${EC2_PUBLIC_IP} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/ai-product-insights-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Attendre que SSH soit prêt
sleep 60

# Déployer
ansible-playbook -i inventory.ini playbook.yml -e "gemini_api_key=..." -vv
```

### **Destroy l'infrastructure**
```bash
cd infrastructure/terraform
terraform destroy -var-file=terraform.tfvars -auto-approve
```

---

## 🐛 **Troubleshooting**

### **Erreur : "AWS credentials not found"**
```bash
# Vérifier
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Re-export si vide
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

### **Erreur : "SSH connection refused"**
```bash
# Attendre plus longtemps
sleep 90

# Tester manuellement
ssh -i ~/.ssh/ai-product-insights-key.pem ec2-user@34.xxx.xxx.xxx
```

### **Erreur : "Permission denied (publickey)"**
```bash
# Vérifier les permissions
ls -la ~/.ssh/ai-product-insights-key.pem
# Doit être : -r-------- (permissions 400 ou 600)

# Corriger si nécessaire
chmod 600 ~/.ssh/ai-product-insights-key.pem
```

### **Erreur : "Terraform provider installation failed"**
```bash
cd infrastructure/terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

---

## ✅ **Checklist avant de lancer Jenkins**

- [ ] ✅ Tous les outils installés (Docker, Terraform, Ansible, Trivy, kubectl)
- [ ] ✅ Credentials Jenkins créées (4 credentials)
- [ ] ✅ SSH key copiée et permissions OK (600)
- [ ] ✅ Pipeline Job créé dans Jenkins
- [ ] ✅ GitHub webhook configuré (optionnel pour auto-trigger)
- [ ] ✅ Test local réussi (`./test-pipeline-locally.sh`)

---

## 🎉 **TOUT EST PRÊT!**

**Pour lancer maintenant :**

1. **Test local** : `./test-pipeline-locally.sh` (après export des credentials)
2. **Jenkins** : Build with Parameters → Deploy AWS

**Temps estimé du pipeline complet : ~5-8 minutes**

- Terraform: ~2 min
- EC2 boot: ~1 min
- Ansible: ~3-4 min
