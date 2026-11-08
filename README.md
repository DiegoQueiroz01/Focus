# Focus

O **Focus** é um aplicativo mobile desenvolvido em Flutter para acompanhamento e gestão de treinos de musculação e atividades aeróbicas, com back-end próprio em Python (FastAPI + PostgreSQL) executado via Docker.

---
## 📱 Funcionalidades

- **Conta:**
  - Cadastro no próprio app com nome, e-mail e senha. A API confere se o domínio do e-mail existe (DNS).
  - Login por e-mail com token JWT (senhas armazenadas com bcrypt).
  - Token guardado com `flutter_secure_storage` e injetado automaticamente em todas as requisições.
  - Sessão restaurada ao reabrir o app; retorno automático ao login quando o token expira.
- **Painel:**
  - Totais da semana atual (segunda a domingo): tempo, treinos, carga total e séries, com gráfico por dia.
  - Sequência de dias seguidos com treino iniciado, e recorde.
  - Mapa de dias com atividade do último ano (estilo GitHub); tocar em um dia mostra as atividades dele.
    1 atividade = azul fraco, 2 = azul médio, 3 = azul intenso, 4 ou mais = roxo azulado.
- **Treinos:**
  - Criar, listar, editar e excluir treinos, com exercícios (grupo muscular, séries, repetições e carga).
  - Botão "Iniciar treino": cronômetro, carga acumulada (repetições × carga de cada série concluída) e
    grupo muscular do último exercício. O progresso fica salvo no aparelho se o app for fechado.
- **Geral:** menu lateral (☰) para trocar de tela, tema claro/escuro e sessão restaurada ao reabrir o app.

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
```

As contas são criadas pela tela de cadastro do app. Para criar uma manualmente:
`docker compose exec api python -m app.cli create-user <email> --name "Seu Nome"`.

As migrações rodam automaticamente na subida do container. A documentação interativa fica em http://localhost:8000/docs.

| Método | Rota | Descrição |
| :--- | :--- | :--- |
| `POST` | `/login` | Retorna o token JWT |
| `POST` | `/register` | Cria a conta (nome, e-mail, senha) e retorna o token |
| `GET` | `/me` | Dados do usuário logado |
| `GET` | `/dashboard/overview?tz_offset_minutes=-180` | Semana atual, sequência e mapa de atividades |
| `GET` | `/workouts?offset=0&limit=20` | Lista paginada de treinos |
| `GET` | `/workouts/{id}` | Detalhes de um treino |
| `POST` | `/workouts` | Cria um treino |
| `PUT` | `/workouts/{id}` | Edita um treino (substitui os exercícios) |
| `DELETE` | `/workouts/{id}` | Exclui um treino (o histórico de sessões continua) |
| `POST` | `/workouts/{id}/sessions` | Inicia uma sessão de treino |
| `GET` | `/sessions?start=&end=&limit=` | Sessões iniciadas no intervalo |
| `GET` | `/sessions/active` | Sessão em andamento (ou `null`) |
| `POST` | `/sessions/{id}/finish` | Finaliza com carga total, séries e último grupo muscular |
| `DELETE` | `/sessions/{id}` | Descarta uma sessão |

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
- `EMAIL_CHECK_DELIVERABILITY=false` desliga a checagem de DNS do e-mail (útil sem internet).
- O PostgreSQL só é exposto em `127.0.0.1`.
- HTTP sem TLS é permitido apenas no build de debug do Android. Em produção, publique a API atrás de HTTPS.
