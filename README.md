# MATHRONAUTS

MATHRONAUTS includes the original Python game and separate native mobile
implementations in this repository. Development uses temporary feature branches;
the versions live together on `main` in separate folders.

| Version | Stack | Location | Current scope |
| --- | --- | --- | --- |
| Desktop original | Python / Pygame Zero | Repository root | Five arithmetic stages |
| iPhone | Swift / SwiftUI / SpriteKit | [mobile/ios](mobile/ios/README.md) | Addition prototype |
| Android | Kotlin / Android Canvas | [mobile/android](mobile/android/README.md) | Five stages, touch controls, local best score |

[![CI](https://github.com/RipLiquid/MATHRONAUTS/actions/workflows/ci.yml/badge.svg)](https://github.com/RipLiquid/MATHRONAUTS/actions/workflows/ci.yml)

MATHRONAUTS is an educational arcade game built in Python that combines space-shooter gameplay with mathematics.

Inspired by classic arcade games such as *Space Invaders*, the player controls a spaceship and solves math problems by shooting the meteor containing the correct answer. The project was originally developed as an ICS3U Computer Science final project with the goal of making mathematics practice more interactive and engaging for younger students.

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

## Project Structure

```text
MATHRONAUTS/
│
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI workflow
│
├── images/                     # Sprites, backgrounds, and animations
├── sounds/                     # Music and sound effects
├── fonts/                      # Game fonts
├── tests/                      # Automated tests
│
├── U11-Final CPT.py            # Main game
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
pip install pgzero
pip install pgzhelper
pip install pytest
```

### 3. Run the Game

```bash
python "U11-Final CPT.py"
```

Depending on your system, you may need to use:

```bash
python3 "U11-Final CPT.py"
```

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

MATHRONAUTS uses automated testing to help verify core game logic and prevent regressions as the project changes.

Tests are located in the `tests/` directory and can be run locally using:

```bash
pytest tests/ -v
```

The repository also includes a GitHub Actions Continuous Integration workflow.

The CI pipeline automatically:

1. Checks out the latest version of the repository.
2. Sets up the Python environment.
3. Installs the required dependencies.
4. Runs the automated test suite.

The workflow runs whenever code is pushed to `main` or a pull request targeting `main` is created.

This provides an automated check that changes do not break previously tested functionality.

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

**Daniyal Tauseef & Clarenz Ferrer**
