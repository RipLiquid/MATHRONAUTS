# MATHRONAUTS

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
* Python `random` module
* Python file I/O

## Project Structure

```text
MATHRONAUTS/
│
├── U11-Final CPT.py       # Main game
├── images/                # Sprites, backgrounds, and animations
├── sounds/                # Music and sound effects
├── fonts/                 # Game fonts
├── tests/                 # Testing files
└── __pycache__/
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/RipLiquid/MATHRONAUTS.git
cd MATHRONAUTS
```

### 2. Install dependencies

Make sure Python 3 is installed, then install the required packages:

```bash
pip install pgzero
pip install pgzhelper
```

### 3. Run the game

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

## Project Background

MATHRONAUTS was developed in 2023 as a final project for ICS3U – Introduction to Computer Science.

The project was designed to demonstrate core programming concepts while exploring how interactive software and game mechanics can be used to make elementary mathematics practice more engaging.

## Author

**Daniyal Tauseef** **& Clarenz Ferrer**

## License

This project was developed for educational purposes. No formal open-source license is currently included in the repository.
