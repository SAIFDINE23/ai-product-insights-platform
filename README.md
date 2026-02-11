# AI Product Insights Platform

## Description
AI Product Insights Platform is a SaaS platform that collects, analyzes (IA/NLP), and visualizes customer feedback at scale using a microservices architecture.

## Global Architecture (High Level)
- **Scraper Service** → ingests feedback (initially from a fake dataset) and stores raw data in PostgreSQL.
- **AI Analysis Service** → performs NLP (sentiment + topic extraction) and stores enriched insights.
- **Stats Service** → aggregates insights into KPIs and trends for dashboards.
- **Frontend Dashboard** → React UI to visualize metrics and trends.

### Data Flow
1. Ingestion → Scraper stores raw feedback in PostgreSQL.
2. Processing → AI Analysis reads raw feedback, writes enriched insights.
3. Aggregation → Stats Service computes KPIs and time-based trends.
4. Visualization → Frontend queries Stats Service APIs.

### Communication
- Service-to-service: REST (FastAPI).
- Data storage: PostgreSQL (shared schema or separated per service).

## Tech Stack
- **Backend**: FastAPI (Python)
- **Frontend**: React + TailwindCSS + Chart.js
- **Database**: PostgreSQL
- **Containerization**: Docker, Docker Compose
- **Orchestration**: Kubernetes (Minikube/Kind for local)
- **CI/CD**: GitHub Actions
- **Security Scans**: Trivy / Snyk (placeholder)
- **Monitoring**: Prometheus + Grafana

## Project Structure
See folder layout in this repository.

## Getting Started (Placeholder)
1. Install Docker & Docker Compose
2. Configure environment variables
3. Run `docker compose up`

## Roadmap (Placeholder)
- MVP ingestion + analysis + dashboard
- Production-ready Kubernetes manifests
- Observability & alerting
