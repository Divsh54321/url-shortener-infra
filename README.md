# URL Shortener — AWS Deployment (Terraform + Ansible)

The production deployment of the [url-shortener](../url-shortener) app, matching the original HLD exactly: a custom VPC with public/private subnets, managed RDS (Postgres) and ElastiCache (Redis) in the private subnets, two app servers behind a real Application Load Balancer, deployed with Ansible.

---

## Architecture

```
Internet
   │
   ▼
ALB (public subnets, 2 AZs) — health-checks GET /health every 15s
   │
   ▼
App Servers x2 (public subnets, different AZs) — stateless, identical
   │
   ├──→ RDS Postgres (private subnet, app-only access)
   └──→ ElastiCache Redis (private subnet, app-only access)
```

**Why public/private subnet split, not just one flat network:** the database holds every URL mapping ever created — there's no legitimate reason for it to be reachable from the internet. Private subnets have no route to the internet gateway at all; combined with security groups scoped to the app servers' security group specifically (not an IP range), this makes RDS and ElastiCache genuinely unreachable from outside the VPC, enforced at the network layer rather than by convention.

**Why app servers sit in the public subnets while RDS/ElastiCache don't:** the app servers are the only thing meant to receive internet traffic (via the ALB) and are stateless by design — any server can serve any request, since all persistent state lives in RDS/Redis, not on the instance itself. This is what makes horizontal scaling and the ALB's health-check-based routing actually work.

---

## Infrastructure (Terraform)

Files, in the order they build on each other:

| File | Contents |
|---|---|
| `provider.tf` | AWS provider, `ap-south-1` |
| `vpc.tf` | VPC, 2 public + 2 private subnets (across 2 AZs — a hard requirement for RDS/ElastiCache/ALB subnet groups, even for a single instance), internet gateway, public route table |
| `security_groups.tf` | `app` (SSH + 8000 from anywhere), `rds` and `redis` (5432/6379 **only** from the `app` security group's ID, not a CIDR range) |
| `database.tf` | RDS Postgres (`db.t3.micro`, single-AZ) + ElastiCache Redis (`cache.t3.micro`, single node), each with a subnet group spanning both private subnets |
| `app_servers.tf` | 2 EC2 instances (`t3.micro`), one per public subnet/AZ |
| `alb.tf` | ALB, target group (health check on `/health`), target group attachments, HTTP listener |
| `outputs.tf` | `rds_endpoint`, `redis_endpoint`, `alb_dns_name` |

```bash
terraform init
terraform plan
terraform apply
```

RDS and ElastiCache both take noticeably longer than plain EC2 to provision (RDS: ~5 minutes, ElastiCache: ~3 minutes) — AWS is standing up a full managed database/cache engine, not just a VM.

### A real cost note

Unlike EC2's older free tier, RDS and ElastiCache on an account created after July 15, 2025 draw from AWS's **credit-based Free Plan**, not separately-free instance hours. `db.t3.micro` single-AZ and the smallest ElastiCache node keep the cost low, but this is not literally $0 — tear down promptly after each session.

---

## Deployment (Ansible)

`inventory.ini` groups both app servers under `[app_servers]`. `playbook.yml` installs Docker, pulls the app image, and runs it with the real RDS/Redis endpoints injected as environment variables — one playbook run configures both servers identically:

```yaml
- name: Run container
  docker_container:
    name: url-shortener
    image: "{{ image }}"
    state: started
    restart_policy: always
    ports:
      - "8000:8000"
    env:
      DB_HOST: "{{ db_host }}"
      DB_PASSWORD: "{{ db_password }}"
      REDIS_HOST: "{{ redis_host }}"
```

```bash
ansible-galaxy collection install community.docker
ansible-playbook -i inventory.ini playbook.yml
```

The app itself reads these via `os.getenv(..., "localhost")` — the same code runs unchanged locally (Docker Compose, defaults apply) and here (real endpoints, explicitly set), with zero code branching between environments.

---

## Verifying it's real, not just "looks deployed"

Tested through the **ALB's DNS name**, never a single instance directly — proof that load balancing and health checks are actually in the path, not bypassed:

```bash
curl -i http://<alb_dns_name>/health

curl -i -X POST http://<alb_dns_name>/shorten \
  -H "Content-Type: application/json" \
  -d '{"long_url":"https://example.com"}'
# → 201 Created

curl -i http://<alb_dns_name>/<short_code>
# → 302 Found, correct Location header
```

Multiple `/shorten` calls in sequence returned sequential short codes (`2`, `3`, ...) — confirming the Postgres sequence is working correctly as the single, atomic source of IDs across both app servers, exactly as designed.

---

## Debugging notes

| Symptom | Cause | Fix |
|---|---|---|
| `redis-cli -h <redis_endpoint>` hangs from a laptop | ElastiCache sits in a private subnet with no internet route — this is the intended protection, not a bug | Only reachable from inside the VPC (e.g. via SSH into an app server); verified the system instead via the ALB end-to-end test |
| `docker build` failed: `open Dockerfile: no such file or directory` | Ran the build from `url-shortener-infra` (the Terraform repo) instead of `url-shortener` (the app repo) — the Dockerfile lives with the app code | `cd` into the correct repo before building |
| No `Dockerfile` existed yet | Local development had used Docker Compose exclusively; a Dockerfile was never added | Added a standard Python slim Dockerfile, same pattern as Project 1 |
| Ansible deprecation warning on `docker_container` re-run | `image_name_mismatch` defaults to `ignore`; pulling a new image tag onto a container still running the old tag doesn't auto-recreate it under current defaults | Known behavior, not an error — the explicit image tag bump (`v3` → `v4`) still took effect correctly on the next apply |

---

## Teardown

```bash
terraform destroy
terraform show   # confirm empty
```

---

## Project Status

- [x] Custom VPC with public/private subnet split
- [x] Security groups enforcing app-only access to RDS/ElastiCache (not open CIDR ranges)
- [x] RDS Postgres + ElastiCache Redis, both in private subnets
- [x] 2 app servers behind a real ALB with health-check-based routing
- [x] Deployed via Ansible — one playbook, both servers configured identically
- [x] Verified end-to-end through the ALB DNS name (write + read paths both confirmed)
- [ ] Secrets Manager for the DB password instead of a hardcoded Terraform value (flagged as a known gap)
- [ ] Rate limiting / abuse prevention on `/shorten` (future extension)
