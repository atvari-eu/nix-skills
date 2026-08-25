{ pkgs, ... }:

{
  home.username = "felschr";
  home.homeDirectory = "/home/felschr";

  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  programs.git = {
    enable = true;
    userName = "myuser";
    userEmail = "myuser@example.com";
  };

  programs.opencode = {
    enable = true;
    settings = {
      theme = "opencode";
    };
  };

  programs.claude-code = {
    enable = true;
  };

  home.stateVersion = "25.05";
}
