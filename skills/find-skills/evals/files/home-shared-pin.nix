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
  };
in
{
  home.username = "felschr";
  home.homeDirectory = "/home/felschr";

  programs.opencode = {
    enable = true;
    skills = {
      "web-design" = "${skillSources.agent-skills}/skills/web-design";
      "react-best-practices" = "${skillSources.agent-skills}/skills/react-best-practices";
    };
  };

  home.stateVersion = "25.05";
}
