# MATHRONAUTS

MATHRONAUTS is an educational space-shooter game where players solve arithmetic problems by shooting the meteor containing the correct answer.

Originally developed in Python for a 2023 ICS3U Computer Science final project, it now includes an enhanced desktop launcher, native iOS and Android apps, and an optional AWS leaderboard on desktop.

## Versions

| Platform | Technologies | Location | Features |
|---|---|---|---|
| Desktop | Python, Pygame Zero | Repository root | Five arithmetic stages |
| Desktop enhanced | Python, Pygame Zero | [Optional launcher](desktop/README.md) | Difficulty, practice, review, local statistics and optional AWS leaderboard |
| iOS | Swift, SwiftUI, SpriteKit | [iOS app](mobile/ios/README.md) | Five stages, difficulty, offline practice and statistics |
| Android | Kotlin, Android Canvas | [Android app](mobile/android/README.md) | Five stages, difficulty, offline practice and statistics |

See the **[mobile setup guide](mobile/README.md)** for build instructions, requirements, and downloading mobile build artifacts.

## Gameplay

Solve each question and fire at the correct answer meteor before the wave reaches your defense line.

- Earn **10 points** for each correct answer.
- Start with **three lives**.
- Lose a life for an incorrect answer or a wave reaching the defense line.
- Progress through **addition, subtraction, multiplication, division, and mixed operations**.

Both mobile apps also offer **Easy, Normal, and Hard** difficulty and an untimed
**Practice Mode** with operation selection, ten-question results, answer review,
and learning statistics saved on the device. See the [mobile guide](mobile/README.md).

The original **`U11-Final CPT.py` stays unchanged**. Run **`python MATHRONAUTS.py`**
to enable the same offline learning features through a separate Pygame launcher.
See the [desktop extension guide](desktop/README.md).

## Optional online leaderboard

The enhanced desktop menu includes **Online leaderboard** for the selected
difficulty. After a completed Arcade round, choose **Submit score**, enter a
3–16 character nickname, and submit. The top ten scores are ranked separately
for Easy, Normal and Hard. Practice scores stay local.

Requests run in the background with a five-second network timeout. Gameplay and
local progress work without a connection; no account or AWS credentials are
needed to play. Only opening rankings or explicitly submitting a score contacts
the service. Submissions store the nickname, difficulty, score and a server
timestamp in DynamoDB through an AWS Lambda HTTPS endpoint.

This is a small demo leaderboard: scores are client-submitted, nicknames are
not unique accounts, and each submitted round is a separate entry. AWS usage
is subject to the owner's account allowances and credits. Native mobile
leaderboards are not implemented yet. See the [AWS setup and API](aws/leaderboard/README.md).

## Overview

A math question appears on the screen while four meteors, each containing a possible answer, move toward the player's mothership.

The player must solve the problem, identify the meteor containing the correct answer, and destroy it before the meteors reach the mothership.

Correct answers increase the player's score and progress the game. Incorrect answers result in the loss of a life.

## Levels

MATHRONAUTS progresses through five stages of increasing variety:

| Level | Math Skill       |
| ----- | ---------------- |
| 1     | Addition         |
| 2     | Subtraction      |
| 3     | Multiplication   |
| 4     | Division         |
| 5     | Mixed Operations |

The final level randomly generates questions using all four arithmetic operations.

## Features

* Randomly generated math problems
* Multiple-choice answers displayed on moving meteors
* Player-controlled spaceship
* Mouse-controlled aiming and shooting
* Three-life health system
* Addition, subtraction, multiplication, and division
* Progressive level system
* Score and high-score tracking
* Persistent score storage
* Explosion and damage animations
* Background music and sound effects
* Randomized answer positions
* Custom selection-sort implementation for the high-score leaderboard
* Automated testing with Pytest
* Continuous Integration with GitHub Actions
* Optional desktop leaderboard with AWS Lambda and DynamoDB

## Controls

| Control    | Action        |
| ---------- | ------------- |
| `W`        | Move up       |
| `A`        | Move left     |
| `S`        | Move down     |
| `D`        | Move right    |
| Mouse      | Aim spaceship |
| Left Click | Shoot         |

## Technologies

* Python
* Pygame Zero
* PGZero Helper (`pgzhelper`)
* Pytest
* GitHub Actions
* Python `random` module
* Python file I/O
* AWS Lambda and Amazon DynamoDB (optional desktop leaderboard)

## Project Structure

```text
MATHRONAUTS/
├── .github/workflows/          # Python, Android and iOS CI
├── aws/leaderboard/            # Lambda source and manual deployment guide
├── desktop/                    # Enhanced game, offline rules and online client
├── mobile/
│   ├── android/                # Native Kotlin app
│   └── ios/                    # Native SwiftUI/SpriteKit app
├── tests/                      # Game rules and desktop leaderboard tests
├── images/                     # Original sprites and backgrounds
├── sounds/                     # Original audio assets
├── fonts/                      # Original fonts
├── MATHRONAUTS.py              # Enhanced desktop entry point
├── U11-Final CPT.py            # Preserved original 2023 game
├── requirements-desktop.txt
└── README.md
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/RipLiquid/MATHRONAUTS.git
cd MATHRONAUTS
```

### 2. Install Dependencies

Make sure Python 3 is installed, then install the required packages:

```bash
python -m pip install -r requirements-desktop.txt
python -m pip install pytest
```

### 3. Run the Game

For the enhanced desktop game:

```powershell
python MATHRONAUTS.py
```

To run the preserved original game instead:

```powershell
python "U11-Final CPT.py"
```

The original entry point retains its historical file and audio assumptions.
The enhanced launcher skips the inherited background-music asset if it cannot
be decoded. Install the pinned requirements: the similarly named PyPI
`pgzhelper` package is not the Actor helper used by this project.

## Technical Implementation

### Dynamic Question Generation

Questions are generated at runtime according to the player's current level. The game calculates the correct answer alongside three randomly generated incorrect answers and assigns them to different meteors.

Division problems are generated so that their results are whole numbers.

### Collision Detection

The game detects collisions between bullets and meteors. When a meteor is hit, its assigned value is compared with the correct answer to the current math problem.

A correct hit increases the player's score and generates a new problem. An incorrect hit reduces the player's remaining lives.

### Level Progression

The game tracks successfully completed questions and advances the player through increasingly varied mathematical operations:

```text
Addition
   |
Subtraction
   |
Multiplication
   |
Division
   |
Mixed Operations
```

### High-Score System

Scores are stored locally and loaded when the game starts. A custom selection-sort implementation sorts previous scores in descending order, allowing the highest scores to be displayed on the game-over screen.

## Testing and Continuous Integration

Run the offline checks from the repository root:

```powershell
python -m pytest tests/ -v
python MATHRONAUTS.py --smoke-test desktop-test-artifacts
```

The Python suite covers arithmetic, progression, local persistence, leaderboard
request/response handling, network failures and optional UI transitions. These
tests simulate network responses and do not need AWS. The desktop smoke check
loads the preserved game and exercises actual projectile collisions, a full
Practice round, results, statistics and storage reset, then saves screenshots.

Check the deployed AWS connection separately:

```powershell
python -m desktop.check_leaderboard
```

This reads all three difficulty rankings and validates their response structure
and ordering. It never inserts test scores or deletes entries. Availability of
the live service is required for this check; ordinary gameplay remains offline.

GitHub Actions runs Python tests, desktop smoke, a separate **AWS Leaderboard
Connection** check, Android tests/builds, and iOS tests/simulator builds for pull
requests into `main` and pushes to `main`. The Python workflow also supports
manual runs. CI does not deploy the Lambda source or replace manual playtesting.
See the [desktop](desktop/README.md) and [mobile](mobile/README.md) guides.

## Learning Outcomes

Developing MATHRONAUTS provided practical experience with several fundamental programming and software development concepts, including:

* Event-driven programming
* Game loops
* Collision detection
* Randomized content generation
* File input/output
* Sorting algorithms
* Lists and state management
* Sprite animation
* User input handling
* Game state and progression systems
* Automated testing
* Continuous Integration
* Git and GitHub workflows

## Project Background

MATHRONAUTS was developed in 2023 as a final project for ICS3U – Introduction to Computer Science.

The project was designed to demonstrate core programming concepts while exploring how interactive software and game mechanics can be used to make elementary mathematics practice more engaging.

The project has since been maintained and improved with modern development practices, including automated testing and Continuous Integration through GitHub Actions.

## Authors

**Daniyal Tauseef & Clarenz Ferrer** — original 2023 base project.

Further development by Daniyal Tauseef.
