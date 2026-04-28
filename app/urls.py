from django.contrib import admin
from django.urls import path
from django.http import HttpResponse


def home(request: object) -> HttpResponse:
    """Placeholder home view — replace with your own."""
    return HttpResponse("Coming soon.")


urlpatterns = [
    path('admin/', admin.site.urls),
    path('', home),
]
