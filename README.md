# Lab #8 — Infraestructura como Código con Terraform (Azure)

**Curso:** ARSW / BluePrints  
**Estudiante:** Julian Eduardo Arenas Alfonso  
**Correo:** julian.arenas-a@mail.escuelaing.edu.co  
**Fecha:** Abril 2026  
**Repositorio:** https://github.com/Julian54628/ARSWLabTerraform

---

## Descripción

Este laboratorio implementa una arquitectura de alta disponibilidad en Microsoft Azure usando **Terraform** como herramienta de Infraestructura como Código (IaC). Se despliegan 2 máquinas virtuales Linux con nginx detrás de un **Azure Load Balancer público (L4)**, con backend remoto para el state de Terraform en Azure Storage y un pipeline de CI/CD en GitHub Actions.

---

## Arquitectura

```
Internet
    |
    | HTTP :80
    ▼
[Azure Load Balancer - IP Pública: 20.104.26.82]
    |           |
    ▼           ▼
[lab8-vm-0] [lab8-vm-1]
  nginx         nginx
    \           /
     [subnet-web]
     [lab8-vnet 10.10.0.0/16]
     [lab8-rg - canadacentral]
```

### Componentes desplegados

| Recurso | Nombre | Descripción |
|---|---|---|
| Resource Group | `lab8-rg` | Contenedor principal en canadacentral |
| Virtual Network | `lab8-vnet` | Red 10.10.0.0/16 |
| Subnet web | `subnet-web` | 10.10.1.0/24 — VMs y LB |
| Subnet mgmt | `subnet-mgmt` | 10.10.2.0/24 — gestión |
| Load Balancer | `lab8-lb` | SKU Standard, IP pública estática |
| IP Pública | `lab8-lb-pip` | 20.104.26.82 |
| VM 0 | `lab8-vm-0` | Ubuntu 22.04, Standard_B1s, nginx |
| VM 1 | `lab8-vm-1` | Ubuntu 22.04, Standard_B1s, nginx |
| NIC 0 | `lab8-nic-0` | Interfaz de red VM 0 |
| NIC 1 | `lab8-nic-1` | Interfaz de red VM 1 |
| NSG | `lab8-web-nsg` | Puerto 80 abierto, SSH solo desde IP del estudiante |
| Storage Account | `sttfstate2lab8` | Backend remoto del state de Terraform |

---

## Estructura del repositorio

```
.
├── infra/
│   ├── main.tf              # Resource Group y wiring de módulos
│   ├── providers.tf         # Provider AzureRM >= 4.0, backend azurerm
│   ├── variables.tf         # Declaración de variables
│   ├── outputs.tf           # lb_public_ip, resource_group_name, vm_names
│   ├── backend.hcl          # Configuración del backend remoto (sin secretos)
│   ├── cloud-init.yaml      # Instala nginx y publica hostname
│   └── env/
│       └── dev.tfvars       # Variables del entorno de desarrollo
├── modules/
│   ├── vnet/                # Módulo de red virtual y subnets
│   ├── compute/             # Módulo de NICs y VMs Linux
│   └── lb/                  # Módulo de Load Balancer, NSG y asociaciones
├── .github/
│   └── workflows/
│       └── terraform.yml    # Pipeline CI/CD
└── README.md
```

---

## Requisitos previos

- Azure CLI >= 2.85
- Terraform >= 1.6
- Cuenta Azure (Azure for Students)
- Llave SSH Ed25519 generada

---

## Instrucciones de despliegue

### 1. Crear el backend remoto

```bash
az group create --name rg-tfstate-lab8 --location canadacentral

az storage account create \
  --resource-group rg-tfstate-lab8 \
  --name sttfstate2lab8 \
  --location canadacentral \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name sttfstate2lab8
```

### 2. Configurar backend.hcl

```hcl
resource_group_name  = "rg-tfstate-lab8"
storage_account_name = "sttfstate2lab8"
container_name       = "tfstate"
key                  = "terraform.tfstate"
```

### 3. Configurar variables

Editar `infra/env/dev.tfvars` con tu IP pública y alias:

```hcl
prefix              = "lab8"
location            = "canadacentral"
vm_count            = 2
admin_username      = "student"
ssh_public_key      = "~/.ssh/id_ed25519.pub"
allow_ssh_from_cidr = "TU_IP/32"
tags = {
  owner   = "tu-alias"
  course  = "ARSW"
  env     = "dev"
  expires = "2026-04-30"
}
```

### 4. Desplegar

```bash
cd infra
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -var-file=env/dev.tfvars -out plan.tfplan
terraform apply "plan.tfplan"
```

### 5. Verificar

```bash
curl http://$(terraform output -raw lb_public_ip)
# Respuesta: "Hola desde lab8-vm-0" o "lab8-vm-1"
```

### 6. Destruir al terminar

```bash
terraform destroy -var-file=env/dev.tfvars
```

---

## Evidencias

### terraform plan — 18 recursos a crear

<img width="1904" height="658" alt="image" src="https://github.com/user-attachments/assets/f5ee0889-b853-4385-a130-1082f67a6805" />

---

### terraform apply — despliegue exitoso

<img width="995" height="136" alt="image" src="https://github.com/user-attachments/assets/1715db95-46e0-4a54-a405-3067be05ae58" />

---

### Load Balancer respondiendo — VM 0

<img width="1034" height="118" alt="image" src="https://github.com/user-attachments/assets/507422ca-bbdf-4288-b143-e470226fb0e2" />

---

### Load Balancer respondiendo — VM 1

<img width="1034" height="118" alt="image" src="https://github.com/user-attachments/assets/01528f77-26ba-4fe3-b59a-3ec8215f58ce" />

---

### Recursos en Azure Portal

<img width="1892" height="830" alt="image" src="https://github.com/user-attachments/assets/5582ff5d-8133-459b-a462-28449d54c962" />

---

### GitHub Actions — workflow ejecutándose

<img width="793" height="234" alt="image" src="https://github.com/user-attachments/assets/4fc05231-17c1-40b2-80b8-0f6fec298778" />

---

### GitHub Actions — detalle del error de autenticación

<img width="1875" height="856" alt="image" src="https://github.com/user-attachments/assets/a19703cd-b264-4b1f-8168-41e237daf556" />

---

## Pipeline CI/CD

El archivo `.github/workflows/terraform.yml` define dos jobs:

- **terraform-plan**: Se ejecuta automáticamente en cada `push` o `pull_request` a `main`. Corre `fmt`, `validate` y `plan`, y sube el plan como artefacto.
- **terraform-apply**: Se ejecuta manualmente con `workflow_dispatch` solo desde `main`, usando el environment `production`.

**Nota sobre autenticación:** La cuenta institucional de Azure for Students no permite la creación de Service Principals ni aplicaciones en Azure Active Directory (`AADSTS700016`), lo que impide configurar OIDC o credenciales de Service Principal para el pipeline. El workflow está correctamente estructurado para recibir las credenciales via el secret `AZURE_CREDENTIALS` en cuanto se disponga de una suscripción con permisos de administrador de directorio.

---

## Seguridad implementada

- **SSH por llave Ed25519**: Las VMs no aceptan autenticación por contraseña.
- **NSG con mínimo privilegio**: Puerto 80 abierto desde Internet, puerto 22 solo desde la IP del estudiante (`179.13.167.114/32`).
- **Backend remoto con state locking**: El state de Terraform se guarda en Azure Storage con bloqueo para evitar operaciones concurrentes.
- **Tags en todos los recursos**: `owner`, `course`, `env`, `expires` en cada recurso para trazabilidad y gestión de costos.
- **Sin credenciales en el código**: `backend.hcl` y `dev.tfvars` no contienen llaves privadas ni secretos.

---

## Reflexión técnica

### Decisiones de diseño

Se eligió un **Azure Load Balancer L4** en lugar de un Application Gateway (L7) porque el caso de uso es simple distribución de tráfico HTTP sin necesidad de inspección de contenido, path-based routing ni terminación SSL. El LB L4 es más económico y suficiente para el objetivo del lab.

La región **canadacentral** fue seleccionada porque la suscripción Azure for Students de la Escuela tiene restricciones de política que bloquean el despliegue en `eastus` y `westus2`. Esto es un trade-off aceptable para el lab, aunque en producción se elegiría la región más cercana a los usuarios finales.

### Trade-offs

| Decisión | Ventaja | Desventaja |
|---|---|---|
| LB L4 vs Application Gateway | Menor costo (~$0.02/h vs ~$0.25/h) | Sin routing por path, sin WAF |
| Standard_B1s para VMs | Costo mínimo (~$0.01/h) | Poca CPU para cargas reales |
| NSG en NICs vs Subnet | Más granular por VM | Más recursos a gestionar |
| canadacentral | Única región disponible | Latencia mayor desde Colombia |

### Estimación de costos

Con el despliegue activo durante 8 horas de trabajo:

| Recurso | Costo/hora | Total 8h |
|---|---|---|
| 2x VM Standard_B1s | $0.012 c/u | ~$0.19 |
| Load Balancer Standard | $0.025 | ~$0.20 |
| IP Pública Standard | $0.004 | ~$0.03 |
| Storage Account (state) | ~$0.001 | ~$0.01 |
| **Total aproximado** | | **~$0.43 USD** |

### ¿Por qué es importante destruir al terminar?

Los recursos en Azure generan costos mientras existen, incluso si no reciben tráfico. El comando `terraform destroy` elimina todo de forma ordenada y reproducible, dejando el estado limpio. Al tener el código en el repositorio, se puede volver a desplegar en minutos cuando sea necesario.

---

## Limpieza

```bash
# Destruir infraestructura principal
terraform destroy -var-file=env/dev.tfvars

# Destruir backend (solo al finalizar el curso)
az group delete --name rg-tfstate-lab8 --yes --no-wait
```

---

## Preguntas de reflexión

**¿Por qué L4 LB vs Application Gateway (L7)?**  
El LB L4 opera a nivel de transporte (TCP/UDP) y es ideal cuando solo se necesita distribuir tráfico sin inspeccionar el contenido HTTP. El Application Gateway opera a nivel de aplicación y permite routing por path, afinidad de sesión por cookie, y WAF. Para este lab el L4 es suficiente y más económico.

**¿Qué implicaciones de seguridad tiene exponer 22/TCP?**  
Exponer SSH directamente a Internet (aunque restringido por IP) es un riesgo porque la IP puede cambiar y porque es un vector de ataque si la llave privada se compromete. La mitigación ideal es usar **Azure Bastion**, que provee acceso SSH a través del portal de Azure sin exponer el puerto 22.

**¿Qué mejoras haría si fuera producción?**  
VM Scale Set para autoscaling, Application Gateway con WAF, Azure Bastion, Azure Monitor con alertas, pipeline con OIDC sin secretos de larga duración, y múltiples zonas de disponibilidad para alta disponibilidad real.
