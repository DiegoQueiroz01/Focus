# Focus

O **Focus** é um aplicativo mobile desenvolvido em Flutter para acompanhamento e gestão de treinos de musculação e atividades aeróbicas, com back-end próprio em Python (FastAPI + PostgreSQL) executado via Docker.

---
## 📱 Funcionalidades

- **Autenticação:**
  - Login contra a API com token JWT (senhas armazenadas com bcrypt).
  - Token guardado com `flutter_secure_storage` e injetado automaticamente em todas as requisições.
  - Sessão restaurada ao reabrir o app; retorno automático ao login quando o token expira.
- **Dashboard de Progresso:**
  - Resumo dos últimos 7 dias (tempo total de treino e total de séries executadas).
  - Listagem das últimas atividades realizadas.
- **Gestão de Treinos:**
  - Histórico paginado com scroll infinito (lazy loading) e pull-to-refresh.
  - Formulário para inserção de novas sessões (tipo, duração) e adição dinâmica de exercícios (séries, repetições e cargas em kg).
  - Visualização detalhada de cada treino registrado.

---

## 🛠️ Tecnologias Utilizadas

- **App:** [Flutter](https://flutter.dev/) / Dart, `dio`, `flutter_secure_storage`
- **API:** [FastAPI](https://fastapi.tiangolo.com/), SQLAlchemy 2, Alembic, PyJWT, bcrypt
- **Banco de dados:** PostgreSQL 16
- **Infraestrutura:** Docker Compose

---

## 📂 Estrutura do Projeto

```text
focus/
├── docker-compose.yml           # API + PostgreSQL
├── .env.example                 # Variáveis de ambiente (copiar para .env)
├── backend/
│   ├── Dockerfile
│   ├── alembic/                 # Migrações do banco
│   ├── app/
│   │   ├── api/                 # Rotas (auth, dashboard, workouts) e dependências
│   │   ├── core/                # Configuração e segurança (JWT, bcrypt)
│   │   ├── db/                  # Sessão do SQLAlchemy
│   │   ├── models/              # Tabelas: users, workouts, exercises
│   │   ├── schemas/             # Contratos de entrada/saída (Pydantic)
│   │   ├── cli.py               # Comandos administrativos (criar usuário)
│   │   └── main.py
│   └── tests/
├── lib/
│   ├── config/                  # URL base da API
│   ├── models/                  # Treino, Exercicio, Pagina, DashboardResumo
│   ├── service/                 # ApiService (Dio + interceptor JWT) e TokenStorage
│   ├── views/                   # Telas (Login, Dashboard, Treinos, Form, Detalhes)
│   └── main.dart
└── pubspec.yaml
```

---

## Como Executar o Projeto

### Pré-requisitos
- [Docker](https://docs.docker.com/get-docker/) com Docker Compose.
- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e configurado.

### 1. Back-end

```bash
cp .env.example .env
# Preencha POSTGRES_PASSWORD e JWT_SECRET_KEY no .env
docker compose up -d --build
docker compose exec api python -m app.cli create-user <seu-usuario>
```

As migrações rodam automaticamente na subida do container. A documentação interativa fica em http://localhost:8000/docs.

| Método | Rota | Descrição |
| :--- | :--- | :--- |
| `POST` | `/login` | Retorna o token JWT |
| `GET` | `/dashboard/summary?days=7` | Totais de treinos, séries e minutos do usuário |
| `GET` | `/workouts?offset=0&limit=20` | Histórico paginado |
| `POST` | `/workouts` | Registra uma nova sessão de treino |

Testes da API:

```bash
docker run --rm -v "$PWD/backend:/src" -w /src python:3.12-slim \
  sh -c "pip install -q -r requirements-dev.txt && pytest -q"
```

### 2. App Flutter

```bash
flutter pub get
flutter run
```

Por padrão o app usa `http://10.0.2.2:8000` no emulador Android e `http://localhost:8000` nas demais plataformas. Para outro endereço (dispositivo físico ou produção):

```bash
flutter run --dart-define=API_BASE_URL=https://api.seudominio.com
```

Para Flutter Web, libere a origem do app no `.env`: `CORS_ORIGINS` para endereços fixos ou, em desenvolvimento (porta aleatória), `CORS_ORIGIN_REGEX=^http://(localhost|127\.0\.0\.1):\d+$`.

---

## Nota sobre Segurança

- O `.env` não é versionado; segredos ficam apenas nele.
- O PostgreSQL só é exposto em `127.0.0.1`.
- HTTP sem TLS é permitido apenas no build de debug do Android. Em produção, publique a API atrás de HTTPS.
