function ua-drop-caches --wraps='sudo paccache -rk3; sudo aura -Sc --noconfirm' --description 'alias ua-drop-caches sudo paccache -rk3; sudo aura -Sc --noconfirm'
  sudo paccache -rk3; sudo aura -Sc --noconfirm $argv
        
end
