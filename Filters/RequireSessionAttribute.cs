using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace TestProject.Filters;

/// <summary>
/// Action filter that ensures an active user session exists in HttpContext.Session before executing any controller action.
/// Halts execution and returns 401 Unauthorized if no active session is found or if the session has expired.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
public class RequireSessionAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        var session = context.HttpContext.Session;
        var loginId = session.GetInt32("LoginID");
        var userName = session.GetString("UserName");

        if (!loginId.HasValue || string.IsNullOrEmpty(userName))
        {
            context.Result = new UnauthorizedObjectResult(new
            {
                message = "Authentication required. No active session found or session has expired. Please log in."
                
            });
            return;
        }

        base.OnActionExecuting(context);
    }
}
