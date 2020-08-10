module GamePlay
  class Evolve < BaseCleanUpdate
    attr_accessor :evolved
    # Constant telling if you have gifs or not during the scene
    ENABLE_GIF = true
    # Path of the music of the pokemon in evolution
    EVOLVE_MUSIC = 'audio/bgm/pkmrs-evolving'
    # Path of the music of the pokemon in evolved
    EVOLVED_MUSIC = 'audio/bgm/xy_trainer_battle_victory'

    FIRST_STEP = 60
    SECOND_STEP_FREQUENCY = 60
    SECOND_STEP = FIRST_STEP + (2.5 * SECOND_STEP_FREQUENCY).to_i
    LAST_STEP = SECOND_STEP + 60
    PI2 = Math::PI * 2

    # Launch the Pokemon Evolution scene
    # @param pokemon [PFM::Pokemon] the evolving Pokemon
    # @param id [Integer] the ID of the evolution
    # @param form [Integer] the form of the evolution
    # @param forced [Boolean] if the evolution can be stopped or not
    def initialize(pokemon, id, form = nil, forced = false)
      super()
      @pokemon = pokemon
      @clone = pokemon.clone
      @clone.id = id
      if form
        @clone.form = form
      else
        @clone.form_calibrate(:evolve)
      end
      @forced = forced
      @id_bg = 0
      @evolved = false
      @counter = 0
      memorize_audio
    end

    def update_graphics
      @pokemon_gif&.update(@sprite_pokemon.bitmap)
      @clone_gif&.update(@sprite_clone.bitmap)
      return if $game_temp.message_window_showing

      if @counter == 0
        evolution_first_step
      elsif @counter >= LAST_STEP
        evolution_last_step
        update_message
        munja_evolution
        update_pkmn_id
        # Normal skill learn
        @pokemon.check_skill_and_learn
        # Evovolution skill learn
        @pokemon.check_skill_and_learn(false, 0)
        restore_audio
        @running = false
        @evolved = true
        register_in_pokedex
      elsif @counter < SECOND_STEP && !@forced && Input.trigger?(:B)
        stop_evolution_step
        return
      else
        update_animation
      end
      @counter += 1
    end

    private

    def release_animation
      @sprite_clone.opacity = 0
      @sprite_pokemon.opacity = 255
      @sprite_pokemon.set_color([0, 0, 0, 0])
      @viewport.tone.set(0, 0, 0, 0)
    end

    def stop_evolution_step
      release_animation
      @message_window.stay_visible = false
      display_message(parse_text(31, 1, ::PFM::Text::PKNICK[0] => @pokemon.given_name))
      @running = false
      $game_system.bgm_restore2
    end

    def evolution_first_step 
      Audio.bgm_play(EVOLVE_MUSIC)
      $game_system.cry_play(@pokemon.id)
      @message_window.auto_skip = true
      @message_window.stay_visible = true
      display_message(parse_text(31, 0, ::PFM::Text::PKNICK[0] => @pokemon.given_name))
    end

    def evolution_last_step
      @message_window.stay_visible = false
      Audio.bgm_play(EVOLVED_MUSIC)
      $game_system.cry_play(@clone.id)
      display_message(parse_text(31, 2, ::PFM::Text::PKNICK[0] => @pokemon.given_name,
                                        ::PFM::Text::PKNAME[1] => @clone.name))
    end

    def munja_evolution
      if @clone.id == 291 && $actors.size < 6 && $bag.contain_item?(4)
        munja = PFM::Pokemon.generate_from_hash(
          id: 292,
          level: @pokemon.level,
          exp: @pokemon.exp,
          shiny: @pokemon.shiny,
          captured_in: @pokemon.captured_in,
          trainer_id: @pokemon.trainer_id,
          trainer_name: @pokemon.trainer_name,
          iv_hp: @pokemon.iv_hp,
          iv_atk: @pokemon.iv_atk,
          iv_dfe: @pokemon.iv_dfe,
          iv_spd: @pokemon.iv_spd,
          iv_ats: @pokemon.iv_ats,
          iv_dfs: @pokemon.iv_dfs,
          ev_hp: @pokemon.ev_hp,
          ev_atk: @pokemon.ev_atk,
          ev_dfe: @pokemon.ev_dfe,
          ev_spd: @pokemon.ev_spd,
          ev_ats: @pokemon.ev_ats,
          ev_dfs: @pokemon.ev_dfs,
          skills_set: @pokemon.skills_set
        )
        $actors << munja
        $bag.remove_item(4, 1)
        $pokedex.mark_seen(292, forced: true)
        $pokedex.mark_captured(292)
      end
    end

    def register_in_pokedex
      $pokedex.mark_seen(@pokemon.id, @pokemon.form, forced: true)
      $pokedex.mark_captured(@pokemon.id)
      $pokedex.pokemon_fought_inc(@pokemon.id)
      $pokedex.pokemon_captured_inc(@pokemon.id)
    end

    def memorize_audio
      $game_system.bgm_memorize2
      Audio.bgm_stop
    end

    def restore_audio
      Audio.bgm_stop
      $game_system.bgm_restore2
    end

    def update_animation
      # 1st step: Pokemon start glowing and emit light around
      if @counter < FIRST_STEP
        value = 255 * @counter / FIRST_STEP
        @sprite_pokemon.set_color(Color.new(value, value, value, value))
        value /= 5
        @viewport.tone.set(value, value, value, 0)
      # 2nd step Pokemon switch between the two forms during
      elsif @counter < SECOND_STEP
        value = (Math.cos((@counter - FIRST_STEP) * PI2 / SECOND_STEP_FREQUENCY) + 1) * 128
        @sprite_pokemon.opacity = value
        @sprite_clone.opacity = 255 - value
      # 3rd step Evolution unglow and shows
      elsif @counter < LAST_STEP
        value = (60 - (@counter - SECOND_STEP)) * 255 / 60
        @viewport.tone.set(value, value, value, 0)
        @sprite_clone.set_color(Color.new(value, value, value, value))
      end
    end

    def update_pkmn_id
      @pokemon.id = @clone.id
      @pokemon.form = @clone.form
    end

    def update_message
      while $game_temp.message_window_showing
        @message_window.update
        Graphics.update
      end
    end

    def create_background
      background_filename = Battle::Visual.allocate.send(:background_name)
      @background = Sprite.new(@viewport).set_bitmap(background_filename, :battleback)
    end

    def create_sprite_pkmn
      if ENABLE_GIF && (@pokemon_gif = @pokemon.gif_face)
        add_disposable bitmap = Bitmap.new(@pokemon_gif.width, @pokemon_gif.height)
        @pokemon_gif&.update(bitmap)
      end
      @sprite_pokemon = Sprite::WithColor.new(@viewport).set_bitmap(bitmap || @pokemon.battler_face)
      @sprite_pokemon.set_position(160, 120)
      @sprite_pokemon.set_origin_div(2, 2)
    end

    def create_sprite_pkmn_evolved
      if ENABLE_GIF && (@clone_gif = @clone.gif_face)
        add_disposable bitmap = Bitmap.new(@clone_gif.width, @clone_gif.height)
        @clone_gif&.update(bitmap)
      end
      @sprite_clone = Sprite::WithColor.new(@viewport).set_bitmap(bitmap || @clone.battler_face)
      @sprite_clone.set_position(160, 120)
      @sprite_clone.set_origin_div(2, 2)
      @sprite_clone.set_color([1, 1, 1, 1])
      @sprite_clone.opacity = 0
    end

    def create_graphics
      create_viewport
      create_background
      create_sprite_pkmn
      create_sprite_pkmn_evolved
    end
  end
end
