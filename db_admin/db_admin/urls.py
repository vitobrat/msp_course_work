from django.contrib import admin
from django.urls import path, include


urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('django_db_app.urls')),
    path('auth/', include('django.contrib.auth.urls')),
]
