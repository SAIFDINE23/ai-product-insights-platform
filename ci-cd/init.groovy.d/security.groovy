import jenkins.model.Jenkins
import hudson.security.SecurityRealm
import hudson.security.AuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer
import net.sf.json.JSONObject
import hudson.util.Secret

// ============================================================================
// CONFIGURATION AUTOMATIQUE JENKINS AU DÉMARRAGE
// ============================================================================

def jenkins = Jenkins.getInstance()

// ============================================================================
// 1. CONFIGURATION SÉCURITÉ DE BASE
// ============================================================================

// Activer CSRF Protection
if (jenkins.getCrumbIssuer() == null) {
    jenkins.setCrumbIssuer(new DefaultCrumbIssuer(true))
    println("✓ CSRF Protection enabled")
}

// ============================================================================
// 2. CONFIGURATION JAVA OPTIONS
// ============================================================================

def javaOpts = "-Xmx1g -Xms512m"
System.setProperty("hudson.model.Hudson.logStartupPerformance", "true")

println("✓ Jenkins configuration initialized")
println("✓ Java Options: ${javaOpts}")

// ============================================================================
// 3. SAVE CONFIGURATION
// ============================================================================

jenkins.save()
println("✓ Jenkins configuration saved")
