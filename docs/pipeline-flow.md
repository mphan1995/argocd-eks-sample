# Pipeline Flow

```text
+--------+     +---------+     +----------+
| Gitea  | --> | Jenkins | --> | Registry |
+--------+     +---------+     +----------+
                                 |
                                 v
   Build -> Test -> SBOM -> Scan -> Sign -> Deploy -> Verify
                                 |
                                 v
                           Logs / Artifacts / UI
```
