{
  pkgs,
  ...
}:

let
  skillSources = {
    agent-skills = pkgs.fetchFromGitHub {
      owner = "vercel-labs";
      repo = "agent-skills";
      rev = "0000000000000000000000000000000000000000";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    anthropics-skills = pkgs.fetchFromGitHub {
      owner = "anthropics";
      repo = "skills";
      rev = "1111111111111111111111111111111111111111";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    };
  };
in
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
    skills = {
      "web-design" = "${skillSources.agent-skills}/skills/web-design";
      "pdf" = "${skillSources.anthropics-skills}/skills/pdf";
    };
  };

  programs.claude-code = {
    enable = true;
    skills = {
      "react-best-practices" = "${skillSources.agent-skills}/skills/react-best-practices";
      "pdf" = "${skillSources.anthropics-skills}/skills/pdf";
    };
  };

  home.stateVersion = "25.05";
}
