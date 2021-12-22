# Before contributing

- You certify you own the copyright to the code you're contributing.
- You license all of your changes under the [MIT license](LICENSE.txt) which
  licenses all code within this repository unless otherwise specified in the
  license file.

By opening a pull request to this repository you certify and agree to the above
statements as well as abide by our [NOTICE](NOTICE.txt), [COPYING](COPYING.txt),
and [LICENSE](LICENSE.txt).

If you agree to all of the above then see the sections below for forking,
cloning, and contributing pull requests!  We appreciate any community
contributions.

# Fork this project

[Fork this project][fork] to your own user and propose pull requests from your
fork.

# Cloning this project

Cloning this project from your fork and add an upstream remote.

    git clone git@github.com:<your user>/dependency-deep-scan-utilities.git

Add the upstream repository to your local clone.

    git remote add upstream git@github.com:integralads/dependency-deep-scan-utilities.git

Create a branch based on upstream master to work off of.

    git fetch upstream
    git checkout upstream/master -b newfeature

# Opening a pull request

- Before opening a pull request ensure that every commit filled out with [a
  short subject line and a description body][great-commits].
  - The first line should be a short description around 50 characters.
  - The second line MUST be blank.
  - All following lines can be a longer description of the change.
- Fill out your pull request title and description with a summary of details
  from your commit messages.

The more details you add to your commits and pull request description will
improve the likelihood your change is accepted and merged.

[fork]: https://help.github.com/articles/fork-a-repo/
[great-commits]: https://chris.beams.io/posts/git-commit/#seven-rules
