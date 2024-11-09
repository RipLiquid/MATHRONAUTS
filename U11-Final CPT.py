"""
author: Daniyal Tauseef
date: 12/14/2023
Comp-sci CPT
"""
#Input
#Processing
#Output

import pgzrun
from pgzhelper import *
import random 
import os
import math

math.cos(0)

WIDTH = 1200
HEIGHT = 800

x,y = WIDTH/2, HEIGHT/2

ship = Actor('spaceship4', (170, 370)) #150, 350
background = 'space'
level_up_background = 'level_up'
mothership = Actor('mothership', (-390, 375))
mothership.scale = 2
damaged_mothership = Actor('damaged_mothership', (-390, 375))
damaged_mothership.scale = 2
mothership_hit = False
hit_time = 3000

speed = 5

bullets = []
bullet_delay = 0

meteor_spawn_points = [120, 280, 440, 600]
current_meteors = []

explosions = []

lives = 3
hearts = [Actor('full_heart', (60 + 100*i, 50)) for i in range(lives)]

mothership_explosion = Actor('mothership_explosion1', (-390, 375))
mothership_explosion.scale = 2
mothership_explosion.images = ['mothership_explosion1', 'mothership_explosion2', 'mothership_explosion3', 'mothership_explosion4', 'mothership_explosion5', 'mothership_explosion6', 'mothership_explosion7']
mothership_explosion.frame = 0
mothership_exploded = False
game_over = False

sounds.background_music.play(-1)

game_over_sound_played = False

levels_list = ['addition', 'subtraction', 'multiplication', 'division', 'all_operations' ]

current_level = 0
current_question = ''
current_answer = 0
questions_finished = 0
level_question_limits = [10, 10, 5, 5, float('inf')]

score = 0
level_seperator = True
level_seperator_time = pygame.time.get_ticks()

scores = []
with open("scores_list",  mode = "r") as f_in:
    lines = f_in.readlines()
    for line in lines:
        scores.append(int(line.strip()))  # Convert the score to an integer and add it to the list
    
Highest_score = max(scores) # Max search

def generate_question():
    global current_question, current_answer
    # Choose operation based on current level
    if current_level == 0:  # Addition
        num1 = random.randint(1, 25)
        num2 = random.randint(1, 25)
        current_question = f'{num1} + {num2} = ?'
        current_answer = num1 + num2
    elif current_level == 1:  # Subtraction
        num1 = random.randint(1, 50)
        num2 = random.randint(1, num1)  # Ensure the result is not negative
        current_question = f'{num1} - {num2} = ?'
        current_answer = num1 - num2
    elif current_level == 2:  # Multiplication
        num1 = random.randint(1, 10)
        num2 = random.randint(1, 10)
        current_question = f'{num1} * {num2} = ?'
        current_answer = num1 * num2
    elif current_level == 3:  # Division
        num1 = random.randint(1, 10)
        num2 = random.randint(1, num1)
        current_question = f'{num1 * num2} / {num2} = ?'  # Ensure the division is exact
        current_answer = num1
    elif current_level == 4:  # Mixed
        # Randomly choose one of the above operations
        operation = random.choice([0, 1, 2, 3])
        if operation == 0:  # Addition
            num1 = random.randint(1, 25)
            num2 = random.randint(1, 25)
            current_question = f'{num1} + {num2} = ?'
            current_answer = num1 + num2
        elif operation == 1:  # Subtraction
            num1 = random.randint(1, 50)
            num2 = random.randint(1, num1)  # Ensure the result is not negative
            current_question = f'{num1} - {num2} = ?'
            current_answer = num1 - num2    
        elif operation == 2:  # Multiplication
            num1 = random.randint(1, 10)
            num2 = random.randint(1, 10)
            current_question = f'{num1} * {num2} = ?'
            current_answer = num1 * num2
        elif operation == 3:  # Division
            num1 = random.randint(1, 10)
            num2 = random.randint(1, num1)
            current_question = f'{num1 * num2} / {num2} = ?'  # Ensure the division is exact
            current_answer = num1  
def draw():
    global score, scores
    if game_over:
        screen.clear()
        screen.draw.text("Game Over", center=(WIDTH / 2, HEIGHT / 2), fontsize=60)
        top_scores = selection_sorting(scores)[:5]
        y = HEIGHT / 2 + 40  
        for i, score in enumerate(top_scores):
            screen.draw.text(f"High Score {i+1}: {score}", midtop=(WIDTH / 2, y), fontsize=30)
            y += 40  
    else:
        if level_seperator:
            screen.blit(level_up_background, (0, 0))  # Replace 'space_background' with your background image
            if current_level == len(levels_list) - 1:  # If this is the final level
                screen.draw.text('Final Level', center=(WIDTH / 2, HEIGHT / 2), fontsize=60)
            else:
                screen.draw.text(f'Level {current_level + 1}', center=(WIDTH / 2, HEIGHT / 2), fontsize=60)
        else:
            screen.blit(background, (0,0))
            ship.draw()
            if mothership_hit:
                damaged_mothership.draw()
            else:
                mothership.draw()
            for bullet in bullets:
                bullet.draw()
            for meteor in current_meteors:  
                meteor.draw()
                screen.draw.text(str(meteor.answer), (meteor.x, meteor.y), fontsize=30)
            for explosion in explosions:
                explosion.draw()
            for heart in hearts:
                heart.draw()
            screen.draw.text(current_question, midbottom = (WIDTH/2, 700), fontsize = 40)
            screen.draw.text(f'Score: {score}', topright = (1170, 30), fontsize = 40)
            screen.draw.text(f'High Score: {Highest_score}', topright = (950, 30), fontsize = 40)

def on_mouse_move(pos):
    ship.angle = ship.angle_to(pos)

def on_mouse_down(button):
    global bullet_delay, questions_finished 
    if button == mouse.LEFT and bullet_delay == 0:
        sounds.bullet_shot.play()
        bullet_delay = 10
        bullet = Actor('bullet')
        bullet.scale = 0.5
        bullet.x = ship.x
        bullet.y = ship.y
        bullet.angle = ship.angle
        bullets.append(bullet)

def update():
    global bullet_delay, mothership_hit, mothership_exploded, game_over, game_over_sound_played, questions_finished, current_level, score, level_seperator, level_seperator_time 
    damage = 0
    if level_seperator:
        if pygame.time.get_ticks() - level_seperator_time > 3000:  # If 3 seconds have passed
            level_seperator = False
            return
    
    if keyboard.W:
        ship.y -= 5
    elif keyboard.S:
        ship.y += 5
    elif keyboard.D:
        ship.x += 5
    elif keyboard.A:
        ship.x -= 5

    if ship.x < 170: #150
        ship.x = 170 #150
    elif ship.x > 200:
        ship.x = 200
    elif ship.y < 80:
        ship.y = 80
    elif ship.y > 720:
        ship.y = 720
   
    if bullet_delay > 0:
        bullet_delay -= 1

    for bullet in bullets:
        bullet.move_forward(15)
        if bullet.y < 0:
            bullets.remove(bullet)

    for meteor in current_meteors:  # Use current_meteors instead of meteors
        meteor.move_in_direction(2)
        if meteor.x < 0:
            current_meteors.remove(meteor)  # Use current_meteors instead of meteors
        if mothership.colliderect(meteor):
            mothership_hit = True
            damage = pygame.time.get_ticks()
            current_meteors.remove(meteor)  # Use current_meteors instead of meteors

    if mothership_hit:
        elapsed_time = pygame.time.get_ticks() - damage
        if elapsed_time > hit_time:
            mothership_hit = False
            if len(hearts) > 0:
                hearts.pop()
                sounds.heart_lost.play()
                if len(hearts) == 0:  # Check if there are no more hearts left
                    sounds.background_music.stop()
                    mothership_exploded = True
                    if not game_over_sound_played:
                        sounds.game_over.play()
                        game_over_sound_played = True
                    clock.schedule_unique(end_game, 5)
            else:
                mothership_exploded = True
                if not game_over_sound_played:
                    sounds.game_over.play()
                    game_over_sound_played = True
                clock.schedule_unique(end_game, 5)

    if mothership_exploded:
        if mothership_explosion.frame < len(mothership_explosion.images):  # Add this condition
            mothership_explosion.frame += 1
        if mothership_explosion.frame == len(mothership_explosion.images):
            mothership_exploded = False
            game_over = True

    for bullet in bullets:
        hit = bullet.collidelist(current_meteors)
        if hit != -1:
            explosion_pos = current_meteors[hit].pos
            if current_meteors[hit].answer == current_answer:
                score += 10
                current_meteors.clear()
                questions_finished += 1
                if questions_finished >= level_question_limits[current_level] and not level_seperator:
                    current_level += 1
                    questions_finished = 0
                    level_seperator = True
                    level_seperator_time = pygame.time.get_ticks()
                    sounds.level_up.play()
                generate_question()
                spawn_meteors()
            else:
                if len(hearts) > 0:
                    hearts.pop()
                    if len(hearts) == 0:  
                        game_over = True
                        if not game_over_sound_played:
                            sounds.game_over.play()
                            game_over_sound_played = True
                        with open("scores_list", mode = "a") as f_out:
                            f_out.write(f"{score}\n")
                current_meteors.remove(current_meteors[hit])

            sounds.meteor_explosion.play()
            sounds.heart_lost.play()
            bullets.remove(bullet) 
            explosion = Actor('explosion1')
            explosion.pos = explosion_pos  
            explosion.images = ['explosion1', 'explosion2', 'explosion3', 'explosion4', 'explosion5', 'explosion6', 'explosion7', 'explosion8']
            explosion.fps = 30
            explosion.time = 15
            explosions.append(explosion)
            
    for explosion in explosions:
        explosion.animate()
        explosion.time -= 1
        if explosion.time == 0:
            explosions.remove(explosion)

    if len(current_meteors) == 0:
        # If so, spawn a new batch
        spawn_meteors()
    
    if game_over:
        sounds.background_music.stop()   

    if questions_finished >= level_question_limits[current_level]:
        current_level += 1
        questions_finished = 0
        level_seperator = True
        level_seperator_time = pygame.time.get_ticks()
        sounds.level_up.play()

def blink_mothership():
    """Allows mothership to blink red when it is hit
    
    Returns:
        bool: Image of damaged mothership
    """
    global damaged_mothership
    if mothership_hit:
        damaged_mothership.draw()
        clock.schedule_interval(blink_mothership, 0.5)

def start_game():
    global level_seperator
    level_seperator = False
clock.schedule_unique(start_game, 3)

def end_game():
    """Ends the game
    
    Returns: 
        bool: Game over screen"""
    global game_over
    game_over = True

def selection_sorting(scores):
    """Sorts the list of scores in an descending order
    
    Args:
        scores (list[float]): The list of scores to be sorted
    """
    for j in range(len(scores)):
        max_index = j
        for i in range(j + 1, len(scores)):
            if scores [i] > scores[max_index]:
                max_index = i
        scores [j], scores[max_index] = scores[max_index], scores[j]
    return scores

def spawn_meteors():
    global questions_finished
    current_meteors.clear()
    meteor_actors = ['meteor1', 'meteor2', 'meteor3', 'meteor4']
    generate_question()

    if current_level in [0, 1]:  # Addition and subtraction levels
        wrong_answers = random.sample(range(1, 50), 3)
    else:
        wrong_answers = random.sample(range(1, 100), 3)

    while current_answer in wrong_answers:
        if current_level in [0, 1]:  # Addition and subtraction levels
            wrong_answers = random.sample(range(1, 50), 3)
        else:
            wrong_answers = random.sample(range(1, 100), 3)

    # Combine correct and wrong answers
    answers = wrong_answers + [current_answer]
    random.shuffle(answers)

    # Spawn a new batch of meteors
    for i in range(len(meteor_actors)):
        meteor = Actor(meteor_actors[i])  # Create a new Actor instance for each meteor
        meteor.x = 1200
        meteor.y = meteor_spawn_points[i]  # Use the corresponding y-coordinate from meteor_spawn_points
        meteor.direction = 180
        meteor.answer = answers[i]  # Assign an answer to the meteor
        current_meteors.append(meteor)

os.environ['SDL_VIDEO_CENTERED'] = '1'
pgzrun.go()