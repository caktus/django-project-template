from django.conf import settings
from django.conf.urls import patterns, include, url
from django.contrib import admin


admin.autodiscover()


urlpatterns = patterns('',
    url(r'^admin/', include(admin.site.urls)),
)


if settings.DEBUG:
    urlpatterns += patterns('',
        url(r'^{0}(?P<path>.*)$'.format(settings.MEDIA_URL.lstrip('/')),
            'django.views.static.serve', {'document_root': settings.MEDIA_ROOT}
        ),
   )
