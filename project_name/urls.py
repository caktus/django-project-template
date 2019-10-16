"""{{ project_name }} URL Configuration

| -- Django URL Patterns -- |

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/{{ docs_version }}/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  url(r'^$', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  url(r'^$', Home.as_view(), name='home')
Including another URLconf
    1. Add an import:  from blog import urls as blog_urls
    2. Add a URL to urlpatterns:  url(r'^blog/', include(blog_urls))
--------------------------------------------------------------------------------
| -- Wagtail URL Patterns for Wagtail Only Projects -- |

urlpatterns = [
    ...
    re_path(r'^documents/', include(wagtaildocs_urls)),
    re_path(r'^admin/', include(wagtailadmin_urls)),
    # must be placed at the end of the urlpattern list (wagtail handles the entire url space)
    re_path(r'', include(wagtail_urls)),
]


"""
from django.conf import settings
from django.conf.urls import url, include, re_path
from django.conf.urls.static import static
from django.contrib import admin
from django.views.generic import TemplateView

from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls
from wagtail.core import urls as wagtail_urls

urlpatterns = [
    url(r'^$', TemplateView.as_view(template_name='home.html')),
    url(r'^admin/', admin.site.urls),
    re_path(r'^cms/', include(wagtailadmin_urls)),
    re_path(r'^documents/', include(wagtaildocs_urls)),
    re_path(r'^pages/', include(wagtail_urls)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    import debug_toolbar
    urlpatterns += [
        url(r'^__debug__/', include(debug_toolbar.urls)),
    ]
