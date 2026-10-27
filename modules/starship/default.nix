# Starship, the fish prompt. Home-manager module, imported by home.nix.
# Laid out after tide's Lean style (two lines, right-aligned items on the first), which
# this replaced. Path, git, the prompt symbol, time and user@host take tide's
# true-color palette. The other right-hand items keep starship's default colours (from
# stylix's palette), minus the bold, which outweighed the left side.
{ lib, ... }:
{
  programs.starship = {
    enable = true;
    presets = [ "nerd-font-symbols" ];
    settings =
      let
        # Like tide, shown only beside a project's marker files, not loose source files (a
        # stray *.py in ~ would otherwise bring up python). Unlike tide, starship looks in
        # the current directory only, not its parents.
        languages = {
          bun = {
            style = "red";
            files = [
              "bun.lock"
              "bun.lockb"
            ];
          };
          crystal = {
            style = "red";
            files = [ "shard.yml" ];
          };
          elixir = {
            style = "purple";
            files = [ "mix.exs" ];
          };
          golang = {
            style = "cyan";
            files = [ "go.mod" ];
          };
          java = {
            style = "red dimmed";
            files = [ "pom.xml" ];
          };
          nodejs = {
            style = "green";
            files = [ "package.json" ];
          };
          php = {
            style = "147";
            files = [ "composer.json" ];
          };
          python = {
            style = "cyan"; # not the default yellow, which duration and direnv also use
            files = [
              ".python-version"
              "Pipfile"
              "__init__.py"
              "pyproject.toml"
              "requirements.txt"
              "setup.py"
            ];
          };
          ruby = {
            style = "red";
            files = [
              "Gemfile"
              "Rakefile"
              ".ruby-version"
            ];
            extensions = [ "gemspec" ];
          };
          rust = {
            style = "red";
            files = [ "Cargo.toml" ];
          };
          zig = {
            style = "yellow";
            files = [ "build.zig" ];
          };
        };
        # Drop the default "via " so the right side reads as a list
        languageModules = lib.mapAttrs (_: l: {
          format = "[$symbol($version )]($style)";
          inherit (l) style;
          detect_extensions = l.extensions or [ ];
          detect_files = l.files;
          detect_folders = [ ];
        }) languages;
      in
      lib.recursiveUpdate languageModules {
        format = lib.concatStrings [
          "$directory"
          "$git_branch"
          "$git_commit"
          "$git_state"
          "$git_status"
          "$fill"
          "$status"
          "$cmd_duration"
          "$username"
          "$hostname"
          "$jobs"
          "$direnv"
          "$bun"
          "$nodejs"
          "$python"
          "$rust"
          "$java"
          "$php"
          "$pulumi"
          "$ruby"
          "$golang"
          "$gcloud"
          "$container"
          "$terraform"
          "$aws"
          "$nix_shell"
          "$crystal"
          "$elixir"
          "$zig"
          "$time"
          "$line_break"
          "$character"
        ];
        aws = {
          format = ''[$symbol($profile )(\($region\) )(\[$duration\] )]($style)'';
          style = "yellow";
        };
        character = {
          success_symbol = "[❯](#5FD700)";
          error_symbol = "[❯](#FF0000)";
          vimcmd_symbol = "[❮](#5FD700)";
        };
        cmd_duration = {
          format = "[$duration]($style) ";
          min_time = 3000;
          style = "yellow";
        };
        container.style = "red dimmed";
        directory = {
          style = "#0087AF";
          before_repo_root_style = "#0087AF";
          # tide's bold "anchor"; it also anchors the last directory, which starship can't
          repo_root_style = "bold #00AFFF";
          truncate_to_repo = false;
          truncation_length = 0;
        };
        direnv = {
          disabled = false;
          format = "[$symbol$allowed]($style) ";
          symbol = "▼";
          style = "bright-yellow";
          allowed_msg = "";
          not_allowed_msg = " not allowed";
          denied_msg = " denied";
        };
        fill.symbol = " ";
        gcloud = {
          format = ''[$symbol$account(@$domain)(\($region\))]($style) '';
          style = "blue";
        };
        git_branch = {
          format = "[$branch]($style) ";
          style = "#5FD700";
        };
        git_state.style = "#FF0000";
        git_status = {
          format = "($all_status$ahead_behind)";
          ahead = "[⇡$count](#5FD700) ";
          behind = "[⇣$count](#5FD700) ";
          diverged = "[⇡$ahead_count⇣$behind_count](#5FD700) ";
          stashed = "[*$count](#5FD700) ";
          conflicted = "[~$count](#FF0000) ";
          staged = "[+$count](#D7AF00) ";
          renamed = "[»$count](#D7AF00) ";
          deleted = "[✘$count](#D7AF00) ";
          modified = "[!$count](#D7AF00) ";
          untracked = "[?$count](#00AFFF) ";
        };
        hostname = {
          format = "[@$hostname]($style) ";
          style = "#D7AF87";
        };
        jobs.style = "blue";
        nix_shell = {
          format = "[$symbol$state]($style) ";
          style = "blue";
        };
        pulumi = {
          format = "[$symbol($username@)$stack]($style) ";
          style = "5";
        };
        python.format = ''[$symbol$pyenv_prefix($version )(\($virtualenv\) )]($style)'';
        status = {
          disabled = false;
          format = "[$symbol$status]($style) ";
          symbol = "✘ ";
          style = "red";
        };
        terraform = {
          format = "[$symbol$workspace]($style) ";
          style = "105";
          detect_extensions = [ ];
        };
        time = {
          disabled = false;
          format = "[$time]($style)";
          style = "#5F8787";
          time_format = "%T";
        };
        username = {
          format = "[$user]($style)";
          style_user = "#D7AF87";
          style_root = "#D7AF00";
        };
      };
  };
}
