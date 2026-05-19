class Crisp < Formula
  desc "Keep everything up-to-date, elegantly"
  homepage "https://github.com/enesdemir/crisp"
  url "https://github.com/enesdemir/crisp/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  version "2.0.0"

  depends_on "bash" => "5.0"

  def install
    libexec.install Dir["*"]

    bin.write_exec_script libexec/"crisp"

    (bash_completion/"crisp").write libexec/"completions/crisp.bash"
    (zsh_completion/"_crisp").write libexec/"completions/crisp.zsh"
    (fish_completion/"crisp.fish").write libexec/"completions/crisp.fish"
  end

  test do
    system "#{bin}/crisp", "--version"
  end
end
