# Focus

O **Focus** é um aplicativo mobile desenvolvido em Flutter para acompanhamento e gestão de treinos de musculação e atividades aeróbicas. O projeto foi desenvolvido como requisito de avaliação prática para a disciplina de Desenvolvimento Mobile.

---
## 📱 Funcionalidades

- **Autenticação Simulada (Mock Login):**
  - Validação de acesso através do arquivo de dados local (`usuarios.json`).
  - Opção de acesso rápido como visitante ("Entrar sem Login").
  - Funcionalidade de encerramento de sessão (Logoff).
- **Dashboard de Progresso:**
  - Resumo de métricas semanais (Tempo total de treino e total de séries executadas).
  - Listagem do histórico das últimas atividades realizadas.
- **Gestão de Treinos:**
  - Listagem das sessões de treino cadastradas.
  - Formulário para inserção de novas sessões e adição dinâmica de exercícios (séries, repetições e cargas em kg).
  - Visualização detalhada de cada treino registrado.
- **Navegação Intuitiva:**
  - Navegação entre telas via `BottomNavigationBar` mantendo estado e fluidez.

---

## 🛠️ Tecnologias Utilizadas

- **Linguagem:** [Dart](https://dart.dev/)
- **Framework:** [Flutter](https://flutter.dev/)
- **Arquitetura:** Estrutura inspirada em MVC (`models`, `views`, `services`)
- **Persistência Temporária:** Leitura de arquivos estáticos em formato JSON (`assets/data/`)

---

## 📂 Estrutura do Projeto

```text
focus/
├── assets/
│   └── data/
│       ├── treinos.json         # Dados estáticos dos treinos e histórico
│       └── usuarios.json        # Credenciais do login mockado
├── lib/
│   ├── models/                  # Classes de modelo (Treino, Exercicio)
│   ├── services/                # Serviços de leitura dos arquivos JSON
│   ├── views/                   # Telas da aplicação (Login, Dashboard, Treinos, Form, Detalhes)
│   └── main.dart                # Ponto de entrada do aplicativo
└── pubspec.yaml                 # Configuração de dependências e assets
```

---

## Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e configurado.
- Dispositivo físico configurado ou Emulador/Nativo (Linux/Android) pronto para execução.

### Passo a passo

1. **Clone este repositório:**
   ```bash
   git clone https://github.com/DiegoQueiroz01/Focus.git
   cd focus
   ```

2. **Instale as dependências:**
   ```bash
   flutter pub get
   ```

3. **Execute o aplicativo:**
   ```bash
   flutter run
   ```

---

## Credenciais de Acesso (Mock)

Para testar o fluxo de login autenticado, utilize uma das credenciais abaixo cadastradas no arquivo `assets/data/usuarios.json`:

| Nome | Senha | Perfil |
| :--- | :--- | :--- |
| `User` | `admin` | Administrador |

---

## Nota sobre Segurança e Persistência

**Aviso Acadêmico:** A validação de usuários e a listagem de treinos utilizam arquivos JSON estáticos locais localizados na pasta `assets/data/`. O objetivo desta abordagem é simular a integração com APIs de backend para fins de avaliação prática de interface, navegação e manipulação de estado no Flutter.