#[cfg(any(not(debug_assertions), test))]
use codex_install_context::InstallContext;
#[cfg(any(not(debug_assertions), test))]
use codex_install_context::InstallMethod;
#[cfg(any(not(debug_assertions), test))]
use codex_install_context::StandalonePlatform;

const TERMUX_RELEASES_URL: &str = "https://github.com/pygojrc/codex/releases/latest";

/// Update action the CLI should perform after the TUI exits.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateAction {
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    NpmGlobalLatest,
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    BunGlobalLatest,
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    PnpmGlobalLatest,
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    BrewUpgrade,
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    StandaloneUnix,
    /// Open this repository's Termux release page for a manual, checksum-visible update.
    StandaloneWindows,
}

impl UpdateAction {
    #[cfg(any(not(debug_assertions), test))]
    pub(crate) fn from_install_context(context: &InstallContext) -> Option<Self> {
        match &context.method {
            InstallMethod::Npm => Some(UpdateAction::NpmGlobalLatest),
            InstallMethod::Bun => Some(UpdateAction::BunGlobalLatest),
            InstallMethod::Pnpm => Some(UpdateAction::PnpmGlobalLatest),
            InstallMethod::Brew => Some(UpdateAction::BrewUpgrade),
            InstallMethod::Standalone { platform, .. } => Some(match platform {
                StandalonePlatform::Unix => UpdateAction::StandaloneUnix,
                StandalonePlatform::Windows => UpdateAction::StandaloneWindows,
            }),
            InstallMethod::Other => {
                #[cfg(target_os = "android")]
                {
                    Some(UpdateAction::StandaloneUnix)
                }
                #[cfg(not(target_os = "android"))]
                {
                    None
                }
            }
        }
    }

    /// Returns the command that opens the repository-owned release page. The
    /// Termux build deliberately does not execute an npm package controlled by
    /// another publisher.
    pub fn command_args(self) -> (&'static str, &'static [&'static str]) {
        let _ = self;
        ("termux-open-url", &[TERMUX_RELEASES_URL])
    }

    /// Returns string representation of the command-line arguments for invoking the update.
    pub fn command_str(self) -> String {
        let (command, args) = self.command_args();
        shlex::try_join(std::iter::once(command).chain(args.iter().copied()))
            .unwrap_or_else(|_| format!("{command} {}", args.join(" ")))
    }
}

#[cfg(not(debug_assertions))]
pub fn get_update_action() -> Option<UpdateAction> {
    UpdateAction::from_install_context(InstallContext::current())
}

#[cfg(test)]
mod tests {
    use super::*;
    use codex_utils_absolute_path::AbsolutePathBuf;
    use pretty_assertions::assert_eq;

    #[test]
    fn maps_install_context_to_update_action() {
        let native_release_dir =
            AbsolutePathBuf::from_absolute_path(std::env::temp_dir().join("native-release"))
                .expect("temp dir path should be absolute");

        let expected_other = if cfg!(target_os = "android") {
            Some(UpdateAction::StandaloneUnix)
        } else {
            None
        };
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Other,
                package_layout: None,
            }),
            expected_other
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Npm,
                package_layout: None,
            }),
            Some(UpdateAction::NpmGlobalLatest)
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Bun,
                package_layout: None,
            }),
            Some(UpdateAction::BunGlobalLatest)
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Pnpm,
                package_layout: None,
            }),
            Some(UpdateAction::PnpmGlobalLatest)
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Brew,
                package_layout: None,
            }),
            Some(UpdateAction::BrewUpgrade)
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Standalone {
                    platform: StandalonePlatform::Unix,
                    release_dir: native_release_dir.clone(),
                    resources_dir: Some(native_release_dir.join("codex-resources")),
                },
                package_layout: None,
            }),
            Some(UpdateAction::StandaloneUnix)
        );
        assert_eq!(
            UpdateAction::from_install_context(&InstallContext {
                method: InstallMethod::Standalone {
                    platform: StandalonePlatform::Windows,
                    release_dir: native_release_dir.clone(),
                    resources_dir: Some(native_release_dir.join("codex-resources")),
                },
                package_layout: None,
            }),
            Some(UpdateAction::StandaloneWindows)
        );
    }

    #[test]
    fn every_update_action_opens_repository_release_page() {
        for action in [
            UpdateAction::NpmGlobalLatest,
            UpdateAction::BunGlobalLatest,
            UpdateAction::PnpmGlobalLatest,
            UpdateAction::BrewUpgrade,
            UpdateAction::StandaloneUnix,
            UpdateAction::StandaloneWindows,
        ] {
            assert_eq!(
                action.command_args(),
                ("termux-open-url", &[TERMUX_RELEASES_URL][..])
            );
        }
    }
}
